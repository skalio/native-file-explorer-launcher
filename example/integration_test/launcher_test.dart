// Calls the real macOS or Windows side. Never opens an app or a window.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_file_explorer_launcher/native_file_explorer_launcher.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('launcher_test');
  });

  tearDownAll(() => temp.delete(recursive: true));

  Future<String> createFile(String name) async {
    final file = File(p.join(temp.path, name));
    await file.writeAsString('hello');
    return file.path;
  }

  Matcher throwsLauncherError(FileLauncherError error) => throwsA(
    isA<FileLauncherException>().having((e) => e.error, 'error', error),
  );

  final missing = p.join(Directory.systemTemp.path, 'does-not-exist', 'a.txt');

  testWidgets('lists the apps for text files, default first', (_) async {
    final apps = await NativeFileExplorerLauncher.getApplications('notes.txt');

    expect(apps, isNotEmpty);
    expect(apps.where((a) => a.isDefault), hasLength(lessThanOrEqualTo(1)));
    if (apps.any((a) => a.isDefault)) expect(apps.first.isDefault, isTrue);
    expect(apps.map((a) => a.name), everyElement(isNotEmpty));
  });

  testWidgets('icons decode at the requested size', (_) async {
    final apps = await NativeFileExplorerLauncher.getApplications(
      'notes.txt',
      iconSize: 48,
    );
    final icon = apps.map((a) => a.icon).nonNulls.first;

    final codec = await ui.instantiateImageCodec(icon);
    final image = (await codec.getNextFrame()).image;
    expect((image.width, image.height), (48, 48));
  });

  testWidgets('unknown file types have no apps', (_) async {
    expect(
      await NativeFileExplorerLauncher.getApplications('data.zzqx-unknown'),
      isEmpty,
    );
  });

  testWidgets('showing a missing file fails with fileNotFound', (_) async {
    await expectLater(
      NativeFileExplorerLauncher.showInFileExplorer(missing),
      throwsLauncherError(FileLauncherError.fileNotFound),
    );
  });

  testWidgets('opening a missing file fails with fileNotFound', (_) async {
    await expectLater(
      NativeFileExplorerLauncher.openFile(missing),
      throwsLauncherError(FileLauncherError.fileNotFound),
    );
  });

  testWidgets('opening with a gone app fails with applicationNotFound', (
    _,
  ) async {
    final path = await createFile('notes.txt');
    const gone = AppHandler(id: 'gone-app-for-tests', name: 'Gone');

    await expectLater(
      NativeFileExplorerLauncher.openFile(path, application: gone),
      throwsLauncherError(FileLauncherError.applicationNotFound),
    );
  });

  testWidgets('opening a file no app opens fails with applicationNotFound', (
    _,
  ) async {
    final path = await createFile('data.zzqx-unknown');

    await expectLater(
      NativeFileExplorerLauncher.openFile(path),
      throwsLauncherError(FileLauncherError.applicationNotFound),
    );
  });
}
