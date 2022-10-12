#include "include/native_file_explorer_launcher/native_file_explorer_launcher_plugin.h"

#include <windows.h>
#include <Shlwapi.h>
#include <Shlobj.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <string>

#pragma comment(lib, "Shlwapi.lib")

namespace {

  using flutter::EncodableMap;
  using flutter::EncodableValue;

  // Converts the given UTF-8 string to UTF-16.
  std::wstring Utf16FromUtf8(const std::string &utf8_string) {
    if (utf8_string.empty()) {
      return std::wstring();
    }
    int target_length = ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(), static_cast<int>(utf8_string.length()), nullptr, 0);
    if (target_length == 0) {
      return std::wstring();
    }
    std::wstring utf16_string;
    utf16_string.resize(target_length);
    int converted_length = ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(), static_cast<int>(utf8_string.length()), utf16_string.data(), target_length);
    if (converted_length == 0) {
      return std::wstring();
    }

    return utf16_string;
  }

  // Converts the given std:wstring(UTF-16) to std:string(UTF-8)
  std::string wstring_to_string(const std::wstring &wstr) {
      std::string str;
      size_t size;
      str.resize(wstr.length());
      wcstombs_s(&size, &str[0], str.size() + 1, wstr.c_str(), wstr.size());

      return str;
  }

  // Returns the filePath argument from |method_call| if it is present, otherwise
  // returns an empty string.
  std::string GetFilePathArgument(const flutter::MethodCall<> &method_call) {
    std::string filePath;
    const auto *arguments = std::get_if<EncodableMap>(method_call.arguments());
    if (arguments) {
      auto filePath_it = arguments->find(EncodableValue("filePath"));
      if (filePath_it != arguments->end()) {
        filePath = std::get<std::string>(filePath_it->second);
      }
    }
    return filePath;
  }

  // Returns the applicationPath argument from |method_call| if it is present, otherwise
  // returns an empty string.
  std::string GetApplicationPathArgument(const flutter::MethodCall<>& method_call) {
      std::string applicationPath;
      const auto* arguments = std::get_if<EncodableMap>(method_call.arguments());
      if (arguments) {
          auto applicationPath_it = arguments->find(EncodableValue("applicationPath"));
          if (applicationPath_it != arguments->end()) {
              EncodableValue path = applicationPath_it->second;
              if (!path.IsNull()) {
                  applicationPath = std::get<std::string>(applicationPath_it->second);
              }
          }
      }
      return applicationPath;
  }

  class NativeFileExplorerLauncherPlugin : public flutter::Plugin {
  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);
    NativeFileExplorerLauncherPlugin();

    virtual ~NativeFileExplorerLauncherPlugin();

  private:
    // Called when a method is called on plugin channel;
    void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue> &method_call, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  };

  // static
  void NativeFileExplorerLauncherPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(registrar->messenger(), "native_file_explorer_launcher", &flutter::StandardMethodCodec::GetInstance());
    auto plugin = std::make_unique<NativeFileExplorerLauncherPlugin>();

    channel->SetMethodCallHandler([plugin_pointer = plugin.get()](const auto &call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
      });

    registrar->AddPlugin(std::move(plugin));
  }

  NativeFileExplorerLauncherPlugin::NativeFileExplorerLauncherPlugin() = default;

  NativeFileExplorerLauncherPlugin::~NativeFileExplorerLauncherPlugin() = default;

  std::vector<IAssocHandler*> tempAssocHandler;

  void NativeFileExplorerLauncherPlugin::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue> &method_call, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    std::string filePath = GetFilePathArgument(method_call);
    if (filePath.empty()) {
      result->Error("argument_error", "No URL provided");
      return;
    }

    std::wstring filePath_wide = Utf16FromUtf8(filePath);
    int status = -1;

    if (method_call.method_name().compare("showFileInNativeFileExplorer") == 0) {
      std::wstring selectfilePath = L"/select," + filePath_wide;
      std::wstring defaultApplication = L"explorer.exe";
      status = static_cast<int>(reinterpret_cast<INT_PTR>(::ShellExecute(nullptr, TEXT("open"), defaultApplication.c_str(), selectfilePath.c_str(), nullptr, SW_SHOWNORMAL)));
    } else if (method_call.method_name().compare("launchFile") == 0) {
        std::string applicationPath = GetApplicationPathArgument(method_call); 
        if (applicationPath.empty()) {
            status = static_cast<int>(reinterpret_cast<INT_PTR>(::ShellExecute(nullptr, TEXT("open"), filePath_wide.c_str(), nullptr, nullptr, SW_SHOWNORMAL)));
        } else {
            std::wstring applicationPath_wide = Utf16FromUtf8(applicationPath);
            for (std::size_t i = 0; i < tempAssocHandler.size(); ++i) {
                LPWSTR ppszPath = nullptr;
                tempAssocHandler[i]->GetName(&ppszPath);

                if (applicationPath_wide == ppszPath) {
                    IShellItem* shellItem;
                    HRESULT res = SHCreateItemFromParsingName(filePath_wide.c_str(), NULL, IID_IShellItem, (void**)&shellItem);
                    if (res != S_OK) {
                        result->Error("internal_error", "Failed to open file");
                        return;
                    }

                    IDataObject* dataObject;
                    shellItem->BindToHandler(NULL, BHID_DataObject, __uuidof(dataObject), (void**)&dataObject);
                    tempAssocHandler[i]->Invoke(dataObject);
                    break;
                }
            }

            result->Success(EncodableValue(true));
            return;
        }
    } else if (method_call.method_name().compare("getSupportedApplications") == 0) {
        LPCWSTR ext = PathFindExtensionW(filePath_wide.c_str());
        if (!ext) {
            std::ostringstream error_message;
            error_message << "Failed to find extension in provided filepath " << filePath;
            result->Error("argument_error", error_message.str());
            return;
        }

        std::wstring extension(ext);
        IEnumAssocHandlers* pEnumHandlers = nullptr;
        HRESULT res = SHAssocEnumHandlers(extension.c_str(), ASSOC_FILTER_RECOMMENDED, reinterpret_cast<IEnumAssocHandlers**>(&pEnumHandlers));
        if (res == S_OK) {

            // release and clear previous saved assoc handler
            for (std::size_t i = 0; i < tempAssocHandler.size(); ++i) {
                if (tempAssocHandler[i]) {
                    tempAssocHandler[i]->Release();
                }
            }
            tempAssocHandler.clear();

            IAssocHandler* pAssocHandler = nullptr;
            std::vector<EncodableValue> v;

            while (pEnumHandlers->Next(1, &pAssocHandler, NULL) == S_OK) {
                if (pAssocHandler) {
                    LPWSTR pszName = nullptr;
                    LPWSTR ppszPath = nullptr;
                    LPWSTR ppszIconPath = nullptr;
                    int pIndex = 0;
                    pAssocHandler->GetUIName(&pszName);
                    pAssocHandler->GetName(&ppszPath);
                    pAssocHandler->GetIconLocation(&ppszIconPath, &pIndex);

                    std::wstring wpszName(pszName);
                    std::wstring wppszPath(ppszPath);
                    std::string applicationName = wstring_to_string(wpszName);
                    std::string applicationPath = wstring_to_string(wppszPath);

                    EncodableMap m = EncodableMap();
                    m[EncodableValue("name")] = EncodableValue(applicationName);
                    m[EncodableValue("url")] = EncodableValue(applicationPath);
                    m[EncodableValue("icon")] = EncodableValue();
                    v.push_back(EncodableValue(m));
                    tempAssocHandler.push_back(pAssocHandler);
                }
            }

            if (v.empty()) {
                result->Success(EncodableValue());
                return;
            }

            result->Success(EncodableValue(v));
            return;
        } else {
            std::ostringstream error_message;
            error_message << "Failed to get associated applications for filepath " << filePath << ": SHAssocEnumHandlers error code " << status;
            result->Error("internal_error", error_message.str());
            return;
        }
    } else {
      result->NotImplemented();
      return;
    }

    if (status <= 32) {
      std::ostringstream error_message;
      error_message << "Failed to open " << filePath << ": ShellExecute error code " << status;
      result->Error("open_error", error_message.str());
      return;
    }
    result->Success(EncodableValue(true));
  }
} // namespace

void NativeFileExplorerLauncherPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  NativeFileExplorerLauncherPlugin::RegisterWithRegistrar(flutter::PluginRegistrarManager::GetInstance()->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}