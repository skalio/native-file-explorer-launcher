# native_file_explorer_launcher

A flutter plugin to launch the native file explorer/a file or get a list of supported applications for a desired file.

|  Supported Platforms |            |
|---------|------------|
| Windows | ✅          |
| macOS   | ✅          |


## Usage

To use this plugin, add `native_file_explorer_launcher` as a dependency in your pubspec.yaml file.

```
// launches the native file explorer, i.e. `Finder`for macOS and `Explorer` for Windows and selects the file
bool isSuccessful = await NativeFileExplorerLauncher.showFileInNativeFileExplorer(filePath)

// launches the file using the default application
bool isSuccessful = await NativeFileExplorerLauncher.launchFile(filePath)
```