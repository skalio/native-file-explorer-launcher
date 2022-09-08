import 'dart:async';
import 'package:flutter/services.dart';

class NativeFileExplorerLauncher {
  static const MethodChannel _channel =
      const MethodChannel('native_file_explorer_launcher');

  /// Launches the native desktop file explorer, i.e, 'Finder' for macOS and 'Explorer' for Windows,
  /// and shows the local desktop file, decribed by [filePath] which is passed as an argument,
  /// in native desktop file explorer, with the file being preselected.
  /// 
  /// Could be used to view either a folder or a file, of any type, in the native file explorer of the platform.
  /// NOTE: When using a file's path(not directory's path) make sure to pass the absolute path including the 
  /// extension of the file otherwise might throw [PlatformException].
  ///  
  /// Returns `true` on successully showing the file in the native file explorer of the platform.
  /// 
  /// Currently it only supports two platforms, namely, macos and windows.
  static Future<bool> showFileInNativeFileExplorer(String filePath) async {
    bool result = false;
    try{
      result = await _channel.invokeMethod(
      "showFileInNativeFileExplorer",
      <String, Object>{
        'filePath': filePath.trim(),
        },
      );
    }
    on PlatformException catch (platformError) {
      print("${platformError.toString()})");
    }
    return result;
  }

  /// Launches the local desktop file, decribed by [filePath] which is passed as an argument,
  /// using the default application selected by the user, of desktop for launching this specific file, 
  /// or any other application which is set by the user as default.
  /// 
  /// Make sure to pass the absolute path of the file. 
  /// Might throw [PlatformException] when the file extension is not included in the [filePath].
  /// 
  /// Returns `true` upon successully launching the file.
  /// 
  /// Currently it only supports two platforms, namely, macOS and Windows. For now on macOS, 
  /// only those files and folders which are residing in the (default) Downloads directory can be launched. 
  static Future<bool> launchFile(String filePath) async {
     bool result = false;
     try{
      result = await _channel.invokeMethod(
      "launchFile",
      <String, Object>{
        'filePath': filePath.trim(),
        },
      );
    }
    on PlatformException catch (platformError) {
      print("${platformError.toString()})");
    }
    return result;
  }
}
