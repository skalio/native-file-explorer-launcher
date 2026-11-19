#ifndef FLUTTER_PLUGIN_NATIVE_FILE_EXPLORER_LAUNCHER_PLUGIN_H_
#define FLUTTER_PLUGIN_NATIVE_FILE_EXPLORER_LAUNCHER_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#include <functional>
#include <memory>

#include "messages.g.h"

namespace native_file_explorer_launcher {

class PlatformThread;

class NativeFileExplorerLauncherPlugin : public flutter::Plugin,
                                         public LauncherApi {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  // Must be created on the platform thread.
  NativeFileExplorerLauncherPlugin();
  virtual ~NativeFileExplorerLauncherPlugin();

  NativeFileExplorerLauncherPlugin(const NativeFileExplorerLauncherPlugin&) =
      delete;
  NativeFileExplorerLauncherPlugin& operator=(
      const NativeFileExplorerLauncherPlugin&) = delete;

  void ShowInFileExplorer(
      const std::string& path,
      std::function<void(std::optional<FlutterError> reply)> result) override;
  void OpenFile(
      const std::string& path, const std::string* application_id,
      std::function<void(std::optional<FlutterError> reply)> result) override;
  // Looks the apps up on a worker thread and replies on the platform thread.
  void GetApplications(
      const std::string& file_name, int64_t icon_size,
      std::function<void(ErrorOr<flutter::EncodableList> reply)> result)
      override;

 private:
  std::shared_ptr<PlatformThread> platform_thread_;
};

}  // namespace native_file_explorer_launcher

#endif  // FLUTTER_PLUGIN_NATIVE_FILE_EXPLORER_LAUNCHER_PLUGIN_H_
