//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <file_selector_windows/file_selector_windows.h>
#include <native_file_explorer_launcher/native_file_explorer_launcher_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  NativeFileExplorerLauncherPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("NativeFileExplorerLauncherPlugin"));
}
