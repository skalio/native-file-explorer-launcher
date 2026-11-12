import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_file_explorer_launcher/native_file_explorer_launcher.dart';
import 'package:native_file_explorer_launcher/src/launcher.dart';
import 'package:native_file_explorer_launcher/src/messages.g.dart';

void main() {
  late FakeLauncherApi api;

  setUp(() {
    api = FakeLauncherApi();
    debugLauncherApi = api;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('isSupported', () {
    for (final platform in TargetPlatform.values) {
      final supported =
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows;
      test('is $supported on ${platform.name}', () {
        debugDefaultTargetPlatformOverride = platform;
        expect(NativeFileExplorerLauncher.isSupported, supported);
      });
    }
  });

  group('on unsupported platforms', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.linux);

    test('every method throws an UnsupportedError', () {
      expect(
        () => NativeFileExplorerLauncher.showInFileExplorer('/a.txt'),
        throwsUnsupportedError,
      );
      expect(
        () => NativeFileExplorerLauncher.openFile('/a.txt'),
        throwsUnsupportedError,
      );
      expect(
        () => NativeFileExplorerLauncher.getApplications('a.txt'),
        throwsUnsupportedError,
      );
      expect(
        () => NativeFileExplorerLauncher.getApplications('no-extension'),
        throwsUnsupportedError,
      );
      expect(api.calls, isEmpty);
    });
  });

  group('showInFileExplorer', () {
    test('passes the path through unchanged', () async {
      await NativeFileExplorerLauncher.showInFileExplorer(
        '/tmp/ends in space ',
      );
      expect(api.calls, ['showInFileExplorer(/tmp/ends in space )']);
    });

    test('rejects relative paths', () {
      expect(
        () => NativeFileExplorerLauncher.showInFileExplorer('a.txt'),
        throwsArgumentError,
      );
      expect(api.calls, isEmpty);
    });

    test('accepts Windows paths on Windows', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await NativeFileExplorerLauncher.showInFileExplorer(r'C:\Users\a.txt');
      await NativeFileExplorerLauncher.showInFileExplorer(r'\\server\share\a');
      expect(api.calls, hasLength(2));
      expect(
        () => NativeFileExplorerLauncher.showInFileExplorer('a.txt'),
        throwsArgumentError,
      );
    });
  });

  group('openFile', () {
    test('opens with the default app', () async {
      await NativeFileExplorerLauncher.openFile('/a.txt');
      expect(api.calls, ['openFile(/a.txt, null)']);
    });

    test('opens with the given app', () async {
      const app = AppHandler(
        id: '/Applications/TextEdit.app',
        name: 'TextEdit',
      );
      await NativeFileExplorerLauncher.openFile('/a.txt', application: app);
      expect(api.calls, ['openFile(/a.txt, /Applications/TextEdit.app)']);
    });

    test('rejects relative paths', () {
      expect(
        () => NativeFileExplorerLauncher.openFile('a.txt'),
        throwsArgumentError,
      );
    });
  });

  group('errors', () {
    for (final error in FileLauncherError.values) {
      test('maps the ${error.name} code', () {
        api.error = PlatformException(code: error.name, message: 'details');
        expect(
          NativeFileExplorerLauncher.openFile('/a.txt'),
          throwsA(
            isA<FileLauncherException>()
                .having((e) => e.error, 'error', error)
                .having((e) => e.message, 'message', 'details'),
          ),
        );
      });
    }

    test('maps unknown codes to failed and keeps the code', () {
      api.error = PlatformException(code: 'channel-error');
      expect(
        NativeFileExplorerLauncher.showInFileExplorer('/a.txt'),
        throwsA(
          isA<FileLauncherException>()
              .having((e) => e.error, 'error', FileLauncherError.failed)
              .having((e) => e.message, 'message', 'channel-error'),
        ),
      );
    });

    test('toString names the error and message', () {
      expect(
        const FileLauncherException(
          FileLauncherError.fileNotFound,
          'gone',
        ).toString(),
        'FileLauncherException(fileNotFound: gone)',
      );
      expect(
        const FileLauncherException(FileLauncherError.failed).toString(),
        'FileLauncherException(failed)',
      );
    });
  });

  group('getApplications', () {
    test('sorts the default app first, then by name', () async {
      api.applications = [
        _app('b', 'zed'),
        _app('c', 'Preview', isDefault: true),
        _app('a', 'Atom'),
        _app('d', 'books'),
      ];
      final apps = await NativeFileExplorerLauncher.getApplications('a.pdf');
      expect(apps.map((a) => a.name), ['Preview', 'Atom', 'books', 'zed']);
      expect(apps.first.isDefault, isTrue);
    });

    test('drops duplicate ids', () async {
      api.applications = [_app('a', 'One'), _app('a', 'One again')];
      final apps = await NativeFileExplorerLauncher.getApplications('a.pdf');
      expect(apps, hasLength(1));
    });

    test('passes the icon size and keeps the icon', () async {
      final icon = Uint8List.fromList([1, 2, 3]);
      api.applications = [_app('a', 'A', icon: icon)];
      final apps = await NativeFileExplorerLauncher.getApplications(
        '/some/dir/a.pdf',
        iconSize: 32,
      );
      expect(api.calls, ['getApplications(/some/dir/a.pdf, 32)']);
      expect(apps.single.icon, icon);
    });

    test('returns an empty list for names without extension', () async {
      expect(await NativeFileExplorerLauncher.getApplications('Makefile'), []);
      expect(api.calls, isEmpty);
    });

    test('rejects icon sizes below one', () {
      expect(
        () => NativeFileExplorerLauncher.getApplications('a.pdf', iconSize: 0),
        throwsArgumentError,
      );
    });
  });

  group('AppHandler', () {
    test('is equal by id', () {
      expect(
        const AppHandler(id: 'a', name: 'A'),
        const AppHandler(id: 'a', name: 'B', isDefault: true),
      );
      expect(
        const AppHandler(id: 'a', name: 'A'),
        isNot(const AppHandler(id: 'b', name: 'A')),
      );
      expect(
        const AppHandler(id: 'a', name: 'A').hashCode,
        const AppHandler(id: 'a', name: 'B').hashCode,
      );
    });

    test('toString shows name, default and id', () {
      expect(
        const AppHandler(id: 'x', name: 'A', isDefault: true).toString(),
        'AppHandler(A, default, id: x)',
      );
      expect(
        const AppHandler(id: 'x', name: 'A').toString(),
        'AppHandler(A, id: x)',
      );
    });
  });
}

PlatformApplication _app(
  String id,
  String name, {
  bool isDefault = false,
  Uint8List? icon,
}) => PlatformApplication(id: id, name: name, isDefault: isDefault, icon: icon);

/// Records calls instead of talking to macOS or Windows.
class FakeLauncherApi implements LauncherApi {
  final calls = <String>[];
  List<PlatformApplication> applications = [];
  PlatformException? error;

  Future<T> _answer<T>(String call, T value) async {
    calls.add(call);
    if (error case final error?) throw error;
    return value;
  }

  @override
  Future<void> showInFileExplorer(String path) =>
      _answer('showInFileExplorer($path)', null);

  @override
  Future<void> openFile(String path, String? applicationId) =>
      _answer('openFile($path, $applicationId)', null);

  @override
  Future<List<PlatformApplication>> getApplications(
    String fileName,
    int iconSize,
  ) => _answer('getApplications($fileName, $iconSize)', applications);

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';
}
