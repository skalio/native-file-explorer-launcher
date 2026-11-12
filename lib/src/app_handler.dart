import 'package:flutter/foundation.dart';

import 'launcher.dart';

/// An app that can open a file, as listed by
/// [NativeFileExplorerLauncher.getApplications].
///
/// Pass it to [NativeFileExplorerLauncher.openFile] to open a file with it.
@immutable
final class AppHandler {
  /// Creates an app entry. Useful for tests, the plugin creates the real ones.
  const AppHandler({
    required this.id,
    required this.name,
    this.icon,
    this.isDefault = false,
  });

  /// Identifies the app on the platform.
  ///
  /// The path of the app bundle on macOS, the handler name on Windows.
  /// Treat it as opaque: it is only meant to be passed back to the plugin.
  final String id;

  /// The app's name, as Finder or File Explorer shows it.
  final String name;

  /// The app icon as a square PNG, if the platform has one.
  final Uint8List? icon;

  /// Whether the platform opens this kind of file with this app by default.
  final bool isDefault;

  @override
  bool operator ==(Object other) => other is AppHandler && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AppHandler($name${isDefault ? ', default' : ''}, id: $id)';
}
