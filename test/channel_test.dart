import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_file_explorer_launcher/native_file_explorer_launcher.dart';
import 'package:native_file_explorer_launcher/src/launcher.dart';
import 'package:native_file_explorer_launcher/src/messages.g.dart';

/// Goes through the generated channel code, answering like the platform does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = LauncherApi.pigeonChannelCodec;
  const prefix = 'dev.flutter.pigeon.native_file_explorer_launcher.LauncherApi';

  final received = <String, List<Object?>>{};

  void answer(String method, List<Object?> reply) {
    messenger.setMockMessageHandler('$prefix.$method', (message) async {
      received[method] = codec.decodeMessage(message)! as List<Object?>;
      return codec.encodeMessage(reply);
    });
  }

  setUp(() {
    received.clear();
    debugLauncherApi = LauncherApi();
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    for (final method in [
      'showInFileExplorer',
      'openFile',
      'getApplications',
    ]) {
      messenger.setMockMessageHandler('$prefix.$method', null);
    }
  });

  test('showInFileExplorer sends the path', () async {
    answer('showInFileExplorer', [null]);
    await NativeFileExplorerLauncher.showInFileExplorer('/a.txt');
    expect(received['showInFileExplorer'], ['/a.txt']);
  });

  test('openFile sends the path and app id', () async {
    answer('openFile', [null]);
    await NativeFileExplorerLauncher.openFile(
      '/a.txt',
      application: const AppHandler(id: 'app', name: 'App'),
    );
    expect(received['openFile'], ['/a.txt', 'app']);
  });

  test('getApplications decodes the apps', () async {
    final icon = Uint8List.fromList([137, 80, 78, 71]);
    answer('getApplications', [
      [
        PlatformApplication(id: '1', name: 'One', isDefault: false),
        PlatformApplication(id: '2', name: 'Two', isDefault: true, icon: icon),
      ],
    ]);

    final apps = await NativeFileExplorerLauncher.getApplications('a.pdf');

    expect(received['getApplications'], ['a.pdf', 64]);
    expect(apps.map((a) => (a.id, a.name, a.isDefault)), [
      ('2', 'Two', true),
      ('1', 'One', false),
    ]);
    expect(apps.first.icon, icon);
    expect(apps.last.icon, isNull);
  });

  test('platform errors become FileLauncherExceptions', () async {
    answer('openFile', ['fileNotFound', 'No file at /a.txt', null]);
    await expectLater(
      NativeFileExplorerLauncher.openFile('/a.txt'),
      throwsA(
        isA<FileLauncherException>()
            .having((e) => e.error, 'error', FileLauncherError.fileNotFound)
            .having((e) => e.message, 'message', 'No file at /a.txt'),
      ),
    );
  });

  test('a missing platform side fails instead of hanging', () async {
    await expectLater(
      NativeFileExplorerLauncher.showInFileExplorer('/a.txt'),
      throwsA(
        isA<FileLauncherException>().having(
          (e) => e.error,
          'error',
          FileLauncherError.failed,
        ),
      ),
    );
  });
}
