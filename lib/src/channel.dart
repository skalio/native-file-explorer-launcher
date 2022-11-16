import 'dart:async';
import 'package:flutter/services.dart';
import 'package:native_file_explorer_launcher/native_file_explorer_launcher.dart';

class NativeFileExplorerLauncher {
  /// Communication channel between the Dart- and native-layer
  static const MethodChannel _channel = const MethodChannel('native_file_explorer_launcher');

  /// Launches the native desktop file explorer, i.e, 'Finder' for macOS and 'Explorer' for Windows,
  /// and shows the local desktop file, decribed by [filePath] which is passed as an argument,
  /// in native desktop file explorer, with the file being preselected.
  ///
  /// Could be used to view either a folder or a file, of any type, in the native file explorer of the platform.
  /// NOTE: When using a file's path(not directory's path) make sure to pass the absolute path including the
  /// extension of the file otherwise might throw [PlatformException].
  ///
  /// [filePath] is the absolute path of the file
  ///
  /// Returns `true` on successully showing the file in the native file explorer of the platform.
  ///
  /// Currently it only supports two platforms, namely, macOS and Windows.
  static Future<bool> showFileInNativeFileExplorer(String filePath) async {
    bool result = false;
    try {
      result = await _channel.invokeMethod("showFileInNativeFileExplorer",
          <String, Object>{'filePath': filePath.trim()});
    } on PlatformException catch (platformError) {
      print("${platformError.toString()})");
    }
    return result;
  }

  /// Launches the local desktop file, decribed by [filePath] which is passed as an argument,
  /// using the application in [applicationHandler]. If the applicationPath is null, the default application selected by the user will launch this file.
  ///
  /// Make sure to pass the absolute path of the file.
  /// Might throw [PlatformException] when the file extension is not included in the [filePath] or the application in [applicationHandler] is not can't open this file.
  ///
  /// [filePath] is the absolute path of the file
  /// [applicationHandler] is a handler which described the application that should open the file
  ///
  /// Returns `true` upon successully launching the file.
  ///
  /// Currently it only supports two platforms, namely, macOS and Windows. For now on macOS,
  /// only those files and folders which are residing in the (default) Downloads directory can be launched.
  static Future<bool> launchFile(
      {required String filePath, AppHandler? applicationHandler}) async {
    bool result = false;
    try {
      result = await _channel.invokeMethod("launchFile", <String, Object?>{
        'filePath': filePath.trim(),
        'applicationPath':
            applicationHandler != null ? applicationHandler.url.trim() : null
      });
    } on PlatformException catch (platformError) {
      print("${platformError.toString()})");
    }
    return result;
  }

  /// Get a list of supported applications which can open the file decribed by [filePath]
  ///
  /// Make sure to pass the absolute path of the file.
  /// Might throw [PlatformException] when the file extension is not included in the [filePath].
  /// Icons are currently not supported in Windows.
  ///
  /// [filePath] is the absolute path of the file
  ///
  /// Returns a list of [AppHandler] objects containing metadata of every supported application. If no application is found, it returns an empty list.
  ///
  /// Currently it only supports two platforms, namely, macOS and Windows.
  static Future<List<AppHandler>?> getSupportedApplications(
      String filePath) async {
    List<AppHandler> apps = [];
    try {
      var list = await _channel.invokeMethod("getSupportedApplications",
          <String, Object>{'filePath': filePath.trim()}) as List<Object?>;
      if (list != null) {
        List<Map<dynamic, dynamic>> mapList =
            list.map((e) => e as Map<dynamic, dynamic>).toList();

        mapList.forEach((element) {
          Map<String, dynamic> map = {};
          for (var item in element.keys) {
            map[item.toString()] = element[item];
          }

          final name = map["name"] as String;
          final url = map["url"] as String;
          final icon = map["icon"] as Uint8List?;
          apps.add(AppHandler(name: name, url: url, icon: icon));
        });
      }
    } on PlatformException catch (platformError) {
      print("${platformError.toString()})");
    }

    return apps;
  }
}
