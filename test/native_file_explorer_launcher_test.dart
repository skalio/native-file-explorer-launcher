import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_file_explorer_launcher/native_file_explorer_launcher.dart';

void main() {
  const MethodChannel channel = MethodChannel('native_file_explorer_launcher');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  // test('getPlatformVersion', () async {
  //   expect(await NativeFileExplorerLauncher.platformVersion, '42');
  // });
}
