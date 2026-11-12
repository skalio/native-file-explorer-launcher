#include "include/native_file_explorer_launcher/native_file_explorer_launcher_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "native_file_explorer_launcher_plugin.h"

void NativeFileExplorerLauncherPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  native_file_explorer_launcher::NativeFileExplorerLauncherPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
