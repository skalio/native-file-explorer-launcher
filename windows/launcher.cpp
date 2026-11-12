#include "launcher.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <shobjidl.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <algorithm>
#include <cwctype>

namespace native_file_explorer_launcher {

namespace {

using Microsoft::WRL::ComPtr;

constexpr char kFileNotFound[] = "fileNotFound";
constexpr char kApplicationNotFound[] = "applicationNotFound";
constexpr char kFailed[] = "failed";

FlutterError Error(const char* code, const std::wstring& message) {
  return FlutterError(code, Utf8FromUtf16(message));
}

FlutterError Failed(const std::wstring& action, HRESULT result) {
  wchar_t* text = nullptr;
  ::FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
                       FORMAT_MESSAGE_IGNORE_INSERTS,
                   nullptr, static_cast<DWORD>(result), 0,
                   reinterpret_cast<wchar_t*>(&text), 0, nullptr);
  std::wstring message = action;
  if (text) {
    message += L": ";
    message += text;
    ::LocalFree(text);
    while (!message.empty() && std::iswspace(message.back())) {
      message.pop_back();
    }
  }
  return Error(kFailed, message);
}

// Takes ownership of a string the shell allocated.
std::wstring TakeString(wchar_t* value) {
  std::wstring result = value ? value : L"";
  ::CoTaskMemFree(value);
  return result;
}

// Explorer's parsing rejects forward slashes.
std::wstring WithBackslashes(std::wstring path) {
  std::replace(path.begin(), path.end(), L'/', L'\\');
  return path;
}

// The extension including its dot, or empty when there is none.
std::wstring ExtensionOf(const std::wstring& file_name) {
  const wchar_t* extension = ::PathFindExtensionW(file_name.c_str());
  if (!extension || extension[0] == L'\0' || extension[1] == L'\0') {
    return L"";
  }
  return extension;
}

std::wstring AssocString(ASSOCSTR what, const std::wstring& extension) {
  DWORD size = 0;
  if (::AssocQueryStringW(ASSOCF_INIT_IGNOREUNKNOWN, what, extension.c_str(),
                          nullptr, nullptr, &size) != S_FALSE ||
      size == 0) {
    return L"";
  }
  std::wstring value(size, L'\0');
  if (FAILED(::AssocQueryStringW(ASSOCF_INIT_IGNOREUNKNOWN, what,
                                 extension.c_str(), nullptr, value.data(),
                                 &size))) {
    return L"";
  }
  value.resize(size > 0 ? size - 1 : 0);
  return value;
}

bool EqualsIgnoringCase(const std::wstring& a, const std::wstring& b) {
  return !a.empty() && ::CompareStringOrdinal(a.c_str(), -1, b.c_str(), -1,
                                              TRUE) == CSTR_EQUAL;
}

ComPtr<IEnumAssocHandlers> EnumHandlers(const std::wstring& extension,
                                        ASSOC_FILTER filter) {
  ComPtr<IEnumAssocHandlers> handlers;
  if (extension.empty() ||
      FAILED(::SHAssocEnumHandlers(extension.c_str(), filter, &handlers))) {
    return nullptr;
  }
  return handlers;
}

// Encodes |source| as a |size| pixel square PNG.
std::optional<std::vector<uint8_t>> EncodePng(IWICImagingFactory* factory,
                                              IWICBitmapSource* source,
                                              int size) {
  const UINT pixels = static_cast<UINT>(size);
  ComPtr<IWICBitmapScaler> scaler;
  ComPtr<IWICBitmapSource> converted;
  ComPtr<IStream> stream;
  ComPtr<IWICBitmapEncoder> encoder;
  ComPtr<IWICBitmapFrameEncode> frame;
  WICPixelFormatGUID format = GUID_WICPixelFormat32bppBGRA;
  if (FAILED(factory->CreateBitmapScaler(&scaler)) ||
      FAILED(scaler->Initialize(source, pixels, pixels,
                                WICBitmapInterpolationModeHighQualityCubic)) ||
      FAILED(::WICConvertBitmapSource(GUID_WICPixelFormat32bppBGRA,
                                      scaler.Get(), &converted))) {
    return std::nullopt;
  }
  stream.Attach(::SHCreateMemStream(nullptr, 0));
  if (!stream ||
      FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr,
                                    &encoder)) ||
      FAILED(encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache)) ||
      FAILED(encoder->CreateNewFrame(&frame, nullptr)) ||
      FAILED(frame->Initialize(nullptr)) ||
      FAILED(frame->SetSize(pixels, pixels)) ||
      FAILED(frame->SetPixelFormat(&format)) ||
      FAILED(frame->WriteSource(converted.Get(), nullptr)) ||
      FAILED(frame->Commit()) || FAILED(encoder->Commit())) {
    return std::nullopt;
  }

  STATSTG stat = {};
  if (FAILED(stream->Stat(&stat, STATFLAG_NONAME)) ||
      FAILED(stream->Seek({}, STREAM_SEEK_SET, nullptr))) {
    return std::nullopt;
  }
  std::vector<uint8_t> png(static_cast<size_t>(stat.cbSize.QuadPart));
  ULONG read = 0;
  if (FAILED(stream->Read(png.data(), static_cast<ULONG>(png.size()),
                          &read)) ||
      read != png.size()) {
    return std::nullopt;
  }
  return png;
}

// Classic apps point at an icon resource in an exe or dll. Store apps point
// at an image in their package, given as an indirect "@{...}" string.
std::optional<std::vector<uint8_t>> IconPng(IWICImagingFactory* factory,
                                            const std::wstring& location,
                                            int index, int size) {
  if (location.empty()) {
    return std::nullopt;
  }

  if (location[0] == L'@') {
    wchar_t path[MAX_PATH] = {};
    ComPtr<IWICBitmapDecoder> decoder;
    ComPtr<IWICBitmapFrameDecode> image;
    if (FAILED(::SHLoadIndirectString(location.c_str(), path, MAX_PATH,
                                      nullptr)) ||
        FAILED(factory->CreateDecoderFromFilename(
            path, nullptr, GENERIC_READ, WICDecodeMetadataCacheOnDemand,
            &decoder)) ||
        FAILED(decoder->GetFrame(0, &image))) {
      return std::nullopt;
    }
    return EncodePng(factory, image.Get(), size);
  }

  wchar_t expanded[MAX_PATH] = {};
  if (::ExpandEnvironmentStringsW(location.c_str(), expanded, MAX_PATH) == 0) {
    return std::nullopt;
  }
  HICON icon = nullptr;
  if (::SHDefExtractIconW(expanded, index, 0, &icon, nullptr,
                          static_cast<UINT>(size)) != S_OK ||
      !icon) {
    return std::nullopt;
  }
  ComPtr<IWICBitmap> bitmap;
  std::optional<std::vector<uint8_t>> png;
  if (SUCCEEDED(factory->CreateBitmapFromHICON(icon, &bitmap))) {
    png = EncodePng(factory, bitmap.Get(), size);
  }
  ::DestroyIcon(icon);
  return png;
}

}  // namespace

std::wstring Utf16FromUtf8(std::string_view utf8) {
  if (utf8.empty()) {
    return L"";
  }
  const int length = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring utf16(static_cast<size_t>(length), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        utf16.data(), length);
  return utf16;
}

std::string Utf8FromUtf16(std::wstring_view utf16) {
  if (utf16.empty()) {
    return "";
  }
  const int length = ::WideCharToMultiByte(CP_UTF8, 0, utf16.data(),
                                           static_cast<int>(utf16.size()),
                                           nullptr, 0, nullptr, nullptr);
  std::string utf8(static_cast<size_t>(length), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, utf16.data(),
                        static_cast<int>(utf16.size()), utf8.data(), length,
                        nullptr, nullptr);
  return utf8;
}

bool IsMissing(const std::wstring& path) {
  if (::GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES) {
    return false;
  }
  const DWORD error = ::GetLastError();
  return error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND ||
         error == ERROR_INVALID_NAME || error == ERROR_BAD_NETPATH ||
         error == ERROR_BAD_NET_NAME;
}

std::optional<FlutterError> ShowInFileExplorer(const std::wstring& path) {
  const std::wstring native_path = WithBackslashes(path);
  if (IsMissing(native_path)) {
    return Error(kFileNotFound, L"No file at " + path);
  }
  PIDLIST_ABSOLUTE item = ::ILCreateFromPathW(native_path.c_str());
  if (!item) {
    return Error(kFailed, L"Explorer cannot find " + path);
  }
  const HRESULT result = ::SHOpenFolderAndSelectItems(item, 0, nullptr, 0);
  ::ILFree(item);
  if (FAILED(result)) {
    return Failed(L"Could not show " + path, result);
  }
  return std::nullopt;
}

std::optional<FlutterError> OpenFile(const std::wstring& path,
                                     const std::wstring* application_id) {
  const std::wstring native_path = WithBackslashes(path);
  if (IsMissing(native_path)) {
    return Error(kFileNotFound, L"No file at " + path);
  }
  const DWORD attributes = ::GetFileAttributesW(native_path.c_str());
  const bool is_folder = attributes != INVALID_FILE_ATTRIBUTES &&
                         (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
  const std::wstring extension = ExtensionOf(native_path);

  if (!application_id) {
    // Without a recommended app, Windows would ask the user to pick one.
    ComPtr<IAssocHandler> any;
    ComPtr<IEnumAssocHandlers> handlers =
        EnumHandlers(extension, ASSOC_FILTER_RECOMMENDED);
    if (!is_folder &&
        (!handlers || handlers->Next(1, &any, nullptr) != S_OK)) {
      return Error(kApplicationNotFound, L"No app opens " + path);
    }

    SHELLEXECUTEINFOW info = {sizeof(info)};
    info.fMask = SEE_MASK_FLAG_NO_UI;
    info.lpFile = native_path.c_str();
    info.nShow = SW_SHOWNORMAL;
    if (!::ShellExecuteExW(&info)) {
      const DWORD error = ::GetLastError();
      if (error == ERROR_NO_ASSOCIATION) {
        return Error(kApplicationNotFound, L"No app opens " + path);
      }
      return Failed(L"Could not open " + path, HRESULT_FROM_WIN32(error));
    }
    return std::nullopt;
  }

  // Look the app up again instead of keeping handlers between calls: a
  // handler is only valid for the file type it was listed for.
  ComPtr<IAssocHandler> match;
  if (ComPtr<IEnumAssocHandlers> handlers =
          EnumHandlers(extension, ASSOC_FILTER_NONE)) {
    ComPtr<IAssocHandler> handler;
    while (!match && handlers->Next(1, &handler, nullptr) == S_OK) {
      wchar_t* name = nullptr;
      if (SUCCEEDED(handler->GetName(&name)) &&
          TakeString(name) == *application_id) {
        match = handler;
      }
      handler.Reset();
    }
  }
  if (!match) {
    return Error(kApplicationNotFound,
                 L"No app " + *application_id + L" opens " + path);
  }

  ComPtr<IShellItem> item;
  ComPtr<IDataObject> data;
  HRESULT result = ::SHCreateItemFromParsingName(native_path.c_str(), nullptr,
                                                 IID_PPV_ARGS(&item));
  if (SUCCEEDED(result)) {
    result = item->BindToHandler(nullptr, BHID_DataObject, IID_PPV_ARGS(&data));
  }
  if (SUCCEEDED(result)) {
    result = match->Invoke(data.Get());
  }
  if (FAILED(result)) {
    return Failed(L"Could not open " + path, result);
  }
  return std::nullopt;
}

std::vector<Application> GetApplications(const std::wstring& file_name,
                                         int icon_size) {
  std::vector<Application> apps;
  const std::wstring extension = ExtensionOf(file_name);
  ComPtr<IEnumAssocHandlers> handlers =
      EnumHandlers(extension, ASSOC_FILTER_RECOMMENDED);
  if (!handlers) {
    return apps;
  }

  ComPtr<IWICImagingFactory> factory;
  ::CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER,
                     IID_PPV_ARGS(&factory));
  const std::wstring default_executable =
      AssocString(ASSOCSTR_EXECUTABLE, extension);
  const std::wstring default_name =
      AssocString(ASSOCSTR_FRIENDLYAPPNAME, extension);
  bool found_default = false;

  ComPtr<IAssocHandler> handler;
  while (handlers->Next(1, &handler, nullptr) == S_OK) {
    wchar_t* id = nullptr;
    wchar_t* name = nullptr;
    wchar_t* icon_location = nullptr;
    int icon_index = 0;
    handler->GetName(&id);
    handler->GetUIName(&name);
    handler->GetIconLocation(&icon_location, &icon_index);

    Application app;
    app.id = TakeString(id);
    app.name = TakeString(name);
    const std::wstring location = TakeString(icon_location);
    if (!app.id.empty() && !app.name.empty()) {
      // Windows has no "is default" flag; match what the association says.
      app.is_default = !found_default &&
                       (EqualsIgnoringCase(app.id, default_executable) ||
                        EqualsIgnoringCase(app.name, default_name));
      found_default = found_default || app.is_default;
      if (factory) {
        app.icon = IconPng(factory.Get(), location, icon_index, icon_size);
      }
      apps.push_back(std::move(app));
    }
    handler.Reset();
  }
  return apps;
}

}  // namespace native_file_explorer_launcher
