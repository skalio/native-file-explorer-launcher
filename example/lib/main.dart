import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:native_file_explorer_launcher/native_file_explorer_launcher.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'native_file_explorer_launcher',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const LauncherPage(),
    );
  }
}

class LauncherPage extends StatefulWidget {
  const LauncherPage({super.key});

  @override
  State<LauncherPage> createState() => _LauncherPageState();
}

class _LauncherPageState extends State<LauncherPage> {
  static const _iconSize = 32.0;

  String? _path;
  List<AppHandler> _apps = [];

  String get _fileExplorer =>
      defaultTargetPlatform == TargetPlatform.macOS ? 'Finder' : 'Explorer';

  Future<void> _pickFile() async {
    final file = await openFile();
    if (file == null || !mounted) return;

    final pixels = (_iconSize * MediaQuery.devicePixelRatioOf(context)).ceil();
    final apps = await _run(
      () => NativeFileExplorerLauncher.getApplications(
        file.path,
        iconSize: pixels,
      ),
    );
    setState(() {
      _path = file.path;
      _apps = apps ?? [];
    });
  }

  /// Runs [action] and shows what went wrong, if anything.
  Future<T?> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FileLauncherException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e.error.name}: ${e.message}')),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;

    return Scaffold(
      appBar: AppBar(title: const Text('native_file_explorer_launcher')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FilledButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.file_open),
            label: const Text('Pick a file'),
          ),
          if (path != null) ...[
            const SizedBox(height: 16),
            SelectableText(path),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _run(
                    () => NativeFileExplorerLauncher.showInFileExplorer(path),
                  ),
                  child: Text('Show in $_fileExplorer'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _run(() => NativeFileExplorerLauncher.openFile(path)),
                  child: const Text('Open'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Open with', style: Theme.of(context).textTheme.titleMedium),
            if (_apps.isEmpty) const Text('No app can open this file.'),
            for (final app in _apps)
              _AppTile(
                app: app,
                iconSize: _iconSize,
                onTap: () => _run(
                  () => NativeFileExplorerLauncher.openFile(
                    path,
                    application: app,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.iconSize,
    required this.onTap,
  });

  final AppHandler app;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = app.icon;

    return ListTile(
      leading: icon != null
          ? Image.memory(icon, width: iconSize, height: iconSize)
          : Icon(Icons.apps, size: iconSize),
      title: Text(app.name),
      subtitle: app.isDefault ? const Text('Default') : null,
      onTap: onTap,
    );
  }
}
