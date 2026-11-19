# 2.0.0

A rewrite for current Flutter, macOS and Windows. Breaking: see the
migration notes below.

* Listing apps on macOS is about a hundred times faster. Icons used to be
  sent at every size up to 1024 pixels (15 to 20 MB per file type); they
  are now drawn once at the size you ask for.
* "Open with" on Windows opens the chosen app again. It silently did
  nothing once the app list of another file type had been loaded.
* Windows: app lists come with icons, non-ASCII names and paths are no
  longer garbled, paths with commas can be shown, and nothing leaks.
* The default app is marked and listed first, the rest are sorted by name.
* Failures throw a `FileLauncherException` that says what went wrong,
  instead of printing and returning `false`.
* Replies always come from the platform thread, and listing apps no longer
  blocks it on either platform.
* Swift Package Manager support on macOS. CocoaPods keeps working.
* Requires macOS 12, Flutter 3.41 and Dart 3.11.

## Migrating from 1.x

| 1.x | 2.0 |
| --- | --- |
| `showFileInNativeFileExplorer(path)` returns `bool` | `showInFileExplorer(path)` returns `Future<void>` and throws on failure |
| `launchFile(filePath: path, applicationHandler: app)` | `openFile(path, application: app)` |
| `getSupportedApplications(path)` returns `List<AppHandler>?` | `getApplications(fileName, iconSize: 64)` returns a sorted, non-null list |
| `AppHandler.url` | `AppHandler.id`, plus the new `AppHandler.isDefault` |
| `MissingPluginException` on other platforms | `UnsupportedError`, check `NativeFileExplorerLauncher.isSupported` first |

Paths are no longer trimmed and must be absolute.

# 1.2.1

* use file extension instead file path to get supported applications on macOS

# 1.2.0

* **Breaking change:** `AppMetadata` is renamed to `AppHandler`.
* Add Windows support for supported applications list.

# 1.1.1

* Extend `launchFile()` function.
* Add fallback to earlier macOS version for opening files.

# 1.1.0

* Add 'Open with' functionality (get supported applications).

# 1.0.0

* Initial stable release.