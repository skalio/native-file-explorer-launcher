#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <gtest/gtest.h>

#include <optional>

#include "messages.g.h"
#include "native_file_explorer_launcher_plugin.h"

namespace native_file_explorer_launcher {
namespace test {

namespace {

// Pumps this thread's messages until |done| or a timeout.
bool RunUntil(const bool& done) {
  const ULONGLONG deadline = ::GetTickCount64() + 10000;
  MSG message;
  while (!done && ::GetTickCount64() < deadline) {
    while (::PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
      ::TranslateMessage(&message);
      ::DispatchMessageW(&message);
    }
    ::Sleep(5);
  }
  return done;
}

}  // namespace

TEST(Plugin, GetApplicationsRepliesOnTheCallingThread) {
  ASSERT_TRUE(SUCCEEDED(::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)));
  {
    NativeFileExplorerLauncherPlugin plugin;
    const DWORD platform_thread = ::GetCurrentThreadId();
    DWORD reply_thread = 0;
    std::optional<ErrorOr<flutter::EncodableList>> reply;
    bool done = false;

    plugin.GetApplications("notes.txt", 32,
                           [&](ErrorOr<flutter::EncodableList> result) {
                             reply_thread = ::GetCurrentThreadId();
                             reply = std::move(result);
                             done = true;
                           });

    ASSERT_TRUE(RunUntil(done));
    EXPECT_EQ(reply_thread, platform_thread);
    ASSERT_FALSE(reply->has_error());
    ASSERT_FALSE(reply->value().empty());
    const auto& app = std::any_cast<const PlatformApplication&>(
        std::get<flutter::CustomEncodableValue>(reply->value().front()));
    EXPECT_FALSE(app.id().empty());
    EXPECT_FALSE(app.name().empty());
  }
  ::CoUninitialize();
}

TEST(Plugin, DropsRepliesAfterTheEngineIsGone) {
  ASSERT_TRUE(SUCCEEDED(::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)));
  bool replied = false;
  {
    NativeFileExplorerLauncherPlugin plugin;
    plugin.GetApplications("notes.txt", 16,
                           [&](ErrorOr<flutter::EncodableList>) {
                             replied = true;
                           });
  }
  // The worker finishes after the plugin is gone; nothing may run.
  ::Sleep(2000);
  RunUntil(replied);
  EXPECT_FALSE(replied);
  ::CoUninitialize();
}

TEST(Plugin, ReportsErrorsThroughTheReply) {
  NativeFileExplorerLauncherPlugin plugin;
  std::optional<FlutterError> error;
  plugin.OpenFile("C:\\does\\not\\exist.txt", nullptr,
                  [&](std::optional<FlutterError> reply) { error = reply; });
  ASSERT_TRUE(error.has_value());
  EXPECT_EQ(error->code(), "fileNotFound");
}

}  // namespace test
}  // namespace native_file_explorer_launcher
