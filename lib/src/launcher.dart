import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'app_handler.dart';
import 'exception.dart';
import 'messages.g.dart';

LauncherApi _api = LauncherApi();

/// Replaces the platform side, so tests run without macOS or Windows.
@visibleForTesting
set debugLauncherApi(LauncherApi api) => _api = api;

/// Shows files in Finder or File Explorer, opens them, and lists the apps
/// that can open them.
///
/// Works on macOS and Windows. Everywhere else every method throws an
/// [UnsupportedError], so check [isSupported] first in cross-platform code.
///
/// Failures throw a [FileLauncherException] that says what went wrong.
abstract final class NativeFileExplorerLauncher {
  /// Whether this platform is supported (macOS or Windows).
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Opens a Finder or File Explorer window with the file or folder at
  /// [path] selected.
  ///
  /// [path] must be absolute. Throws a [FileLauncherException] with
  /// [FileLauncherError.fileNotFound] if nothing is there.
  static Future<void> showInFileExplorer(String path) {
    _checkAbsolute(path);
    return _call(() => _api.showInFileExplorer(path));
  }

  /// Opens the file at [path] with [application], or with the default app
  /// when [application] is null.
  ///
  /// [path] must be absolute. Get [application] from [getApplications].
  ///
  /// Throws a [FileLauncherException] with [FileLauncherError.fileNotFound]
  /// if the file is missing, and [FileLauncherError.applicationNotFound] if
  /// the app is gone or no app opens this kind of file.
  static Future<void> openFile(String path, {AppHandler? application}) {
    _checkAbsolute(path);
    return _call(() => _api.openFile(path, application?.id));
  }

  /// Lists the apps that can open files like [fileName], the default app
  /// first and the rest by name.
  ///
  /// Only the extension of [fileName] matters, so a bare name like
  /// `report.pdf` is enough and the file does not need to exist. Names
  /// without an extension get an empty list.
  ///
  /// Icons are square PNGs with [iconSize] pixels per side. For crisp icons,
  /// pass the logical size you draw them at times the device pixel ratio.
  static Future<List<AppHandler>> getApplications(
    String fileName, {
    int iconSize = 64,
  }) async {
    if (iconSize <= 0) {
      throw ArgumentError.value(iconSize, 'iconSize', 'must be positive');
    }
    if (p.extension(fileName).isEmpty) {
      _checkSupported();
      return const [];
    }

    final apps = await _call(() => _api.getApplications(fileName, iconSize));
    final handlers = {
      for (final app in apps)
        app.id: AppHandler(
          id: app.id,
          name: app.name,
          icon: app.icon,
          isDefault: app.isDefault,
        ),
    }.values.toList();
    return handlers..sort(_defaultFirstThenByName);
  }

  static int _defaultFirstThenByName(AppHandler a, AppHandler b) {
    if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static void _checkAbsolute(String path) {
    final style = defaultTargetPlatform == TargetPlatform.windows
        ? p.Style.windows
        : p.Style.posix;
    if (!p.Context(style: style).isAbsolute(path)) {
      throw ArgumentError.value(path, 'path', 'must be absolute');
    }
  }

  static void _checkSupported() {
    if (!isSupported) {
      throw UnsupportedError(
        'NativeFileExplorerLauncher only supports macOS and Windows.',
      );
    }
  }

  static Future<T> _call<T>(Future<T> Function() call) async {
    _checkSupported();
    try {
      return await call();
    } on PlatformException catch (e) {
      final error =
          FileLauncherError.values.asNameMap()[e.code] ??
          FileLauncherError.failed;
      throw FileLauncherException(error, e.message ?? e.code);
    }
  }
}
