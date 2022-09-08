#include "include/native_file_explorer_launcher/native_file_explorer_launcher_plugin.h"

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <string>

namespace
{

  using flutter::EncodableMap;
  using flutter::EncodableValue;

  // Converts the given UTF-8 string to UTF-16.
  std::wstring Utf16FromUtf8(const std::string &utf8_string)
  {
    if (utf8_string.empty())
    {
      return std::wstring();
    }
    int target_length =
        ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                              static_cast<int>(utf8_string.length()), nullptr, 0);
    if (target_length == 0)
    {
      return std::wstring();
    }
    std::wstring utf16_string;
    utf16_string.resize(target_length);
    int converted_length =
        ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                              static_cast<int>(utf8_string.length()),
                              utf16_string.data(), target_length);
    if (converted_length == 0)
    {
      return std::wstring();
    }
    return utf16_string;
  }

  // Returns the filePath argument from |method_call| if it is present, otherwise
  // returns an empty string.
  std::string GetfilePathArgument(const flutter::MethodCall<> &method_call)
  {
    std::string filePath;
    const auto *arguments = std::get_if<EncodableMap>(method_call.arguments());
    if (arguments)
    {
      auto filePath_it = arguments->find(EncodableValue("filePath"));
      if (filePath_it != arguments->end())
      {
        filePath = std::get<std::string>(filePath_it->second);
      }
    }
    return filePath;
  }

  class NativeFileExplorerLauncherPlugin : public flutter::Plugin
  {
  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);
    NativeFileExplorerLauncherPlugin();

    virtual ~NativeFileExplorerLauncherPlugin();

  private:
    // Called when a method is called on plugin channel;
    void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  };

  // static
  void NativeFileExplorerLauncherPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(), "native_file_explorer_launcher",
        &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<NativeFileExplorerLauncherPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  NativeFileExplorerLauncherPlugin::NativeFileExplorerLauncherPlugin() = default;

  NativeFileExplorerLauncherPlugin::~NativeFileExplorerLauncherPlugin() = default;

  void NativeFileExplorerLauncherPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    std::string filePath = GetfilePathArgument(method_call);
    if (filePath.empty())
    {
      result->Error("argument_error", "No URL provided");
      return;
    }
    std::wstring filePath_wide = Utf16FromUtf8(filePath);
    int status;
    if (method_call.method_name().compare("showFileInNativeFileExplorer") == 0)
    {
      std::wstring selectfilePath = L"/select," + filePath_wide;
      std::wstring defaultApplication = L"explorer.exe";
      status = static_cast<int>(reinterpret_cast<INT_PTR>(
          ::ShellExecute(nullptr, TEXT("open"), defaultApplication.c_str(), selectfilePath.c_str(),
                         nullptr, SW_SHOWNORMAL)));
    }
    else if (method_call.method_name().compare("launchFile") == 0)
    {
      status = static_cast<int>(reinterpret_cast<INT_PTR>(
          ::ShellExecute(nullptr, TEXT("open"), filePath_wide.c_str(), nullptr,
                         nullptr, SW_SHOWNORMAL)));
    }
    else
    {
      result->NotImplemented();
      return;
    }
    if (status <= 32)
    {
      std::ostringstream error_message;
      error_message << "Failed to open " << filePath << ": ShellExecute error code "
                    << status;
      result->Error("open_error", error_message.str());
      return;
    }
    result->Success(EncodableValue(true));
  }

} // namespace

void NativeFileExplorerLauncherPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
  NativeFileExplorerLauncherPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}