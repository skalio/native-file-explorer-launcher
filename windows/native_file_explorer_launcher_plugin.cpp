#include "native_file_explorer_launcher_plugin.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <memory>
#include <mutex>
#include <thread>

#include "launcher.h"

namespace native_file_explorer_launcher {

// Runs tasks on the thread that created it, which for the plugin is the
// platform thread: Flutter only takes replies there.
class PlatformThread {
 public:
  PlatformThread() {
    HINSTANCE instance = nullptr;
    ::GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                             GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         reinterpret_cast<LPCWSTR>(&WindowProc), &instance);
    WNDCLASSEXW window_class = {sizeof(window_class)};
    window_class.lpfnWndProc = WindowProc;
    window_class.hInstance = instance;
    window_class.lpszClassName = kWindowClass;
    ::RegisterClassExW(&window_class);
    window_ = ::CreateWindowExW(0, kWindowClass, L"", 0, 0, 0, 0, 0,
                                HWND_MESSAGE, nullptr, instance, nullptr);
  }

  ~PlatformThread() { Close(); }

  PlatformThread(const PlatformThread&) = delete;
  PlatformThread& operator=(const PlatformThread&) = delete;

  // Safe to call from any thread. Drops the task once the plugin is gone.
  void Post(std::function<void()> task) {
    auto owned = std::make_unique<std::function<void()>>(std::move(task));
    std::lock_guard<std::mutex> lock(mutex_);
    if (window_ && ::PostMessageW(window_, kRunTask, 0,
                                  reinterpret_cast<LPARAM>(owned.get()))) {
      owned.release();
    }
  }

  // Call on the creating thread when the plugin goes away. Worker threads
  // may still hold this object; their posts are dropped from then on.
  void Close() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (window_) {
      ::DestroyWindow(window_);
      window_ = nullptr;
    }
  }

 private:
  static constexpr UINT kRunTask = WM_APP + 1;
  static constexpr wchar_t kWindowClass[] =
      L"NativeFileExplorerLauncherPlatformThread";

  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
    if (message == kRunTask) {
      std::unique_ptr<std::function<void()>> task(
          reinterpret_cast<std::function<void()>*>(lparam));
      (*task)();
      return 0;
    }
    return ::DefWindowProcW(window, message, wparam, lparam);
  }

  std::mutex mutex_;
  HWND window_ = nullptr;
};

namespace {

flutter::EncodableValue ToEncodable(const Application& app) {
  PlatformApplication result(Utf8FromUtf16(app.id), Utf8FromUtf16(app.name),
                             app.is_default);
  if (app.icon) {
    result.set_icon(*app.icon);
  }
  return flutter::CustomEncodableValue(std::move(result));
}

}  // namespace

// static
void NativeFileExplorerLauncherPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<NativeFileExplorerLauncherPlugin>();
  LauncherApi::SetUp(registrar->messenger(), plugin.get());
  registrar->AddPlugin(std::move(plugin));
}

NativeFileExplorerLauncherPlugin::NativeFileExplorerLauncherPlugin()
    : platform_thread_(std::make_shared<PlatformThread>()) {}

NativeFileExplorerLauncherPlugin::~NativeFileExplorerLauncherPlugin() {
  platform_thread_->Close();
}

void NativeFileExplorerLauncherPlugin::ShowInFileExplorer(
    const std::string& path,
    std::function<void(std::optional<FlutterError> reply)> result) {
  result(native_file_explorer_launcher::ShowInFileExplorer(
      Utf16FromUtf8(path)));
}

void NativeFileExplorerLauncherPlugin::OpenFile(
    const std::string& path, const std::string* application_id,
    std::function<void(std::optional<FlutterError> reply)> result) {
  std::optional<std::wstring> id;
  if (application_id) {
    id = Utf16FromUtf8(*application_id);
  }
  result(native_file_explorer_launcher::OpenFile(Utf16FromUtf8(path),
                                                 id ? &*id : nullptr));
}

void NativeFileExplorerLauncherPlugin::GetApplications(
    const std::string& file_name, int64_t icon_size,
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  const int size = static_cast<int>(std::clamp<int64_t>(icon_size, 1, 1024));
  std::thread([platform_thread = platform_thread_,
               file_name = Utf16FromUtf8(file_name), size,
               result = std::move(result)]() mutable {
    const HRESULT com = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    std::vector<Application> apps =
        native_file_explorer_launcher::GetApplications(file_name, size);
    if (SUCCEEDED(com)) {
      ::CoUninitialize();
    }

    platform_thread->Post(
        [apps = std::move(apps), result = std::move(result)]() {
          flutter::EncodableList list;
          for (const Application& app : apps) {
            list.push_back(ToEncodable(app));
          }
          result(std::move(list));
        });
  }).detach();
}

}  // namespace native_file_explorer_launcher
