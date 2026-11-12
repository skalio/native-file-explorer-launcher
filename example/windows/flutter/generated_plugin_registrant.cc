//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <file_selector_windows/file_selector_windows.h>
#include <native_file_explorer_launcher/native_file_explorer_launcher_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  NativeFileExplorerLauncherPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("NativeFileExplorerLauncherPluginCApi"));
}
