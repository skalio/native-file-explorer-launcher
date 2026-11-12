#ifndef FLUTTER_PLUGIN_NATIVE_FILE_EXPLORER_LAUNCHER_LAUNCHER_H_
#define FLUTTER_PLUGIN_NATIVE_FILE_EXPLORER_LAUNCHER_LAUNCHER_H_

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "messages.g.h"

// The Windows side of the Dart API, free of Flutter's threading so it can be
// tested on its own. Every function expects COM to be initialized.
namespace native_file_explorer_launcher {

struct Application {
  std::wstring id;
  std::wstring name;
  bool is_default = false;
  std::optional<std::vector<uint8_t>> icon;
};

// Opens an Explorer window with the file or folder at |path| selected.
std::optional<FlutterError> ShowInFileExplorer(const std::wstring& path);

// Opens |path| with the app |application_id| names, or with the default app
// when it is null.
std::optional<FlutterError> OpenFile(const std::wstring& path,
                                     const std::wstring* application_id);

// Lists the apps Windows recommends for files with |file_name|'s extension,
// with square PNG icons of |icon_size| pixels. Can take a while: call it off
// the platform thread.
std::vector<Application> GetApplications(const std::wstring& file_name,
                                         int icon_size);

// Whether nothing is at |path|. Paths Windows refuses to look at count as
// existing, so the shell gets to decide.
bool IsMissing(const std::wstring& path);

std::wstring Utf16FromUtf8(std::string_view utf8);
std::string Utf8FromUtf16(std::wstring_view utf16);

}  // namespace native_file_explorer_launcher

#endif  // FLUTTER_PLUGIN_NATIVE_FILE_EXPLORER_LAUNCHER_LAUNCHER_H_
