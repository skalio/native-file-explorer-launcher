import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_file_explorer_launcher/app_metadata.dart';

class NativeFileExplorerLauncher {
  static const MethodChannel _channel = const MethodChannel('native_file_explorer_launcher');

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
    try {
      result =
          await _channel.invokeMethod("showFileInNativeFileExplorer", <String, Object>{'filePath': filePath.trim()});
    } on PlatformException catch (platformError) {
      print("${platformError.toString()})");
    }
    return result;
  }

  /// Launches the local desktop file, decribed by [filePath] which is passed as an argument,
  /// using the application in [applicationPath]. If the applicationPath is null, the default application selected by the user will launch this file,
  ///
  /// Make sure to pass the absolute path of the file.
  /// Might throw [PlatformException] when the file extension is not included in the [filePath] or the application in [applicationPath] is not available/can't open this file.
  ///
  /// Returns `true` upon successully launching the file.
  ///
  /// Currently it only supports two platforms, namely, macOS and Windows. For now on macOS,
  /// only those files and folders which are residing in the (default) Downloads directory can be launched.
  static Future<bool> launchFile({required String filePath, String? applicationPath}) async {
    bool result = false;
    try {
      result = await _channel.invokeMethod("launchFile", <String, Object?>{'filePath': filePath.trim(), 'applicationPath': applicationPath != null ? applicationPath.trim() : null});
    } on PlatformException catch (platformError) {
      print("${platformError.toString()})");
    }
    return result;
  }

  /// Get a list of supported applications which can open the file decribed by [filePath] 
  /// 
  /// Make sure to pass the absolute path of the file.
  /// Might throw [PlatformException] when the file extension is not included in the [filePath].
  ///
  /// Returns a list of [AppMetadata] objects, which includes the name, url and icon data of every application. NULL if no application can open the file.
  ///
  /// Currently it only supports two platforms, namely, macos and windows.
  static Future<List<AppMetadata>?> getSupportedApplications(String filePath) async {
    List<AppMetadata>? apps;
    try {
      var list = await _channel.invokeMethod("getSupportedApplications", <String, Object>{'filePath': filePath.trim()})
          as List<Object>?;
      if (list != null) {
        apps = [];
        List<Map<dynamic, dynamic>> mapList = list.map((e) => e as Map<dynamic, dynamic>).toList();

        mapList.forEach((element) {
          Map<String, dynamic> map = {};
          for (var item in element.keys) {
            map[item.toString()] = element[item];
          }

          final name = map["name"] as String;
          final url = map["url"] as String;
          final icon = map["icon"] as Uint8List;
          apps!.add(AppMetadata(name, url, icon));
        });
      }
    } on PlatformException catch (platformError) {
      print("${platformError.toString()})");
    }

    return apps;
  }
}
