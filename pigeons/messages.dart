// The interface between the Dart API and the macOS and Windows code.
// After editing, regenerate with:
//   dart run pigeon --input pigeons/messages.dart && dart format lib
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'native_file_explorer_launcher',
    dartOut: 'lib/src/messages.g.dart',
    swiftOut:
        'macos/native_file_explorer_launcher/Sources/native_file_explorer_launcher/Messages.g.swift',
    cppHeaderOut: 'windows/messages.g.h',
    cppSourceOut: 'windows/messages.g.cpp',
    cppOptions: CppOptions(namespace: 'native_file_explorer_launcher'),
  ),
)
/// An app that can open a file, as the platform reports it.
class PlatformApplication {
  PlatformApplication({
    required this.id,
    required this.name,
    required this.isDefault,
    this.icon,
  });

  /// Identifies the app when opening a file with it. Opaque to Dart.
  String id;

  /// The name the platform shows to users.
  String name;

  /// Whether the platform opens this kind of file with this app by default.
  bool isDefault;

  /// A square PNG of the requested size, if the platform has one.
  Uint8List? icon;
}

/// Errors are reported as PlatformException codes: `fileNotFound`,
/// `applicationNotFound`, or `failed`.
@HostApi()
abstract class LauncherApi {
  @async
  void showInFileExplorer(String path);

  /// Opens with the default app when [applicationId] is null.
  @async
  void openFile(String path, String? applicationId);

  /// Looks the apps up by the extension of [fileName]; the file does not
  /// need to exist.
  @async
  List<PlatformApplication> getApplications(String fileName, int iconSize);
}
