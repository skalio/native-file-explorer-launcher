#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <gtest/gtest.h>
#include <shlwapi.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <string>

#include "launcher.h"

// Runs against the real system, but never opens an app or Explorer window.
namespace native_file_explorer_launcher {
namespace test {

namespace {

using Microsoft::WRL::ComPtr;

class LauncherTest : public ::testing::Test {
 protected:
  void SetUp() override {
    ASSERT_TRUE(SUCCEEDED(::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)));
    directory_ = std::filesystem::temp_directory_path() /
                 (L"launcher_test_" + std::to_wstring(::GetCurrentProcessId()));
    std::filesystem::create_directories(directory_);
  }

  void TearDown() override {
    std::error_code ignored;
    std::filesystem::remove_all(directory_, ignored);
    ::CoUninitialize();
  }

  std::wstring MakeFile(const std::wstring& name) {
    const std::filesystem::path path = directory_ / name;
    std::ofstream(path) << "hello";
    return path.wstring();
  }

  std::filesystem::path directory_;
};

// Width and height of a PNG, or zeros if it does not decode.
std::pair<UINT, UINT> PngSize(const std::vector<uint8_t>& png) {
  ComPtr<IWICImagingFactory> factory;
  ComPtr<IStream> stream;
  ComPtr<IWICBitmapDecoder> decoder;
  ComPtr<IWICBitmapFrameDecode> frame;
  UINT width = 0;
  UINT height = 0;
  stream.Attach(::SHCreateMemStream(png.data(), static_cast<UINT>(png.size())));
  if (SUCCEEDED(::CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                   CLSCTX_INPROC_SERVER,
                                   IID_PPV_ARGS(&factory))) &&
      SUCCEEDED(factory->CreateDecoderFromStream(
          stream.Get(), nullptr, WICDecodeMetadataCacheOnDemand, &decoder)) &&
      SUCCEEDED(decoder->GetFrame(0, &frame))) {
    frame->GetSize(&width, &height);
  }
  return {width, height};
}

}  // namespace

TEST(Utf, RoundTripsNonAsciiText) {
  const std::string utf8 = "M\xC3\xBCller \xE6\x97\xA5\xE6\x9C\xAC \xF0\x9F\x93\x84";
  const std::wstring utf16 = Utf16FromUtf8(utf8);
  EXPECT_EQ(utf16, L"M\u00fcller \u65e5\u672c \U0001F4C4");
  EXPECT_EQ(Utf8FromUtf16(utf16), utf8);
  EXPECT_EQ(Utf16FromUtf8(""), L"");
  EXPECT_EQ(Utf8FromUtf16(L""), "");
}

TEST_F(LauncherTest, IsMissingOnlyForMissingPaths) {
  EXPECT_FALSE(IsMissing(directory_.wstring()));
  EXPECT_FALSE(IsMissing(MakeFile(L"a, b \u00e4.txt")));
  EXPECT_TRUE(IsMissing((directory_ / L"missing.txt").wstring()));
  EXPECT_TRUE(IsMissing((directory_ / L"missing" / L"a.txt").wstring()));
}

TEST_F(LauncherTest, ListsAppsForTextFiles) {
  const std::vector<Application> apps = GetApplications(L"notes.txt", 32);
  ASSERT_FALSE(apps.empty());
  for (const Application& app : apps) {
    EXPECT_FALSE(app.id.empty());
    EXPECT_FALSE(app.name.empty());
  }
  EXPECT_LE(std::count_if(apps.begin(), apps.end(),
                          [](const Application& app) { return app.is_default; }),
            1);
}

TEST_F(LauncherTest, OnlyUsesTheExtension) {
  const std::vector<Application> by_name = GetApplications(L"notes.TXT", 16);
  const std::vector<Application> by_path =
      GetApplications(L"C:\\does\\not\\exist.txt", 16);
  ASSERT_EQ(by_name.size(), by_path.size());
  for (size_t i = 0; i < by_name.size(); i++) {
    EXPECT_EQ(by_name[i].id, by_path[i].id);
  }
}

TEST_F(LauncherTest, DrawsIconsAtTheRequestedSize) {
  for (const int size : {16, 48, 128}) {
    const std::vector<Application> apps = GetApplications(L"notes.txt", size);
    const auto with_icon = std::find_if(
        apps.begin(), apps.end(),
        [](const Application& app) { return app.icon.has_value(); });
    ASSERT_NE(with_icon, apps.end()) << "No icon at size " << size;
    EXPECT_EQ(PngSize(*with_icon->icon),
              std::make_pair(static_cast<UINT>(size), static_cast<UINT>(size)));
  }
}

TEST_F(LauncherTest, ReturnsNoAppsWithoutExtension) {
  EXPECT_TRUE(GetApplications(L"Makefile", 16).empty());
  EXPECT_TRUE(GetApplications(L"", 16).empty());
  EXPECT_TRUE(GetApplications(L"ends-with-dot.", 16).empty());
}

TEST_F(LauncherTest, ShowInFileExplorerReportsMissingFiles) {
  const auto error = ShowInFileExplorer((directory_ / L"missing.txt").wstring());
  ASSERT_TRUE(error.has_value());
  EXPECT_EQ(error->code(), "fileNotFound");
}

TEST_F(LauncherTest, OpenFileReportsMissingFiles) {
  const auto error = OpenFile((directory_ / L"missing.txt").wstring(), nullptr);
  ASSERT_TRUE(error.has_value());
  EXPECT_EQ(error->code(), "fileNotFound");
}

TEST_F(LauncherTest, OpenFileReportsMissingApps) {
  const std::wstring gone = L"gone-app-for-tests";
  const auto error = OpenFile(MakeFile(L"notes.txt"), &gone);
  ASSERT_TRUE(error.has_value());
  EXPECT_EQ(error->code(), "applicationNotFound");
}

TEST_F(LauncherTest, OpenFileReportsFilesNoAppOpens) {
  const auto error = OpenFile(MakeFile(L"data.zzqx-unknown"), nullptr);
  ASSERT_TRUE(error.has_value());
  EXPECT_EQ(error->code(), "applicationNotFound");
}

TEST_F(LauncherTest, ErrorMessagesKeepNonAsciiPaths) {
  const auto error =
      ShowInFileExplorer((directory_ / L"M\u00fcller.txt").wstring());
  ASSERT_TRUE(error.has_value());
  EXPECT_NE(error->message().find("M\xC3\xBCller.txt"), std::string::npos);
}

}  // namespace test
}  // namespace native_file_explorer_launcher
