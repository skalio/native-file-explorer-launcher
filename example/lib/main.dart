import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_file_explorer_launcher/app_metadata.dart';
import 'package:native_file_explorer_launcher/native_file_explorer_launcher.dart';

void main() {
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

final GlobalKey<FormState> _filePathFormKey = GlobalKey();

class _MyAppState extends State<MyApp> {
  final TextEditingController _filePathController = new TextEditingController();

  final GlobalKey _openWithButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native File Explorer'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Enter a local file path",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            Container(
              width: 250,
              padding: EdgeInsets.fromLTRB(0, 50, 0, 50),
              child: Form(
                key: _filePathFormKey,
                child: TextFormField(
                  keyboardType: TextInputType.text,
                  controller: _filePathController,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    labelText: "File path ",
                    helperText: "",
                  ),
                  validator: (input) {
                    if (input?.isEmpty ?? true) {
                      return "Please enter a file's path";
                    }
                    return null;
                  },
                ),
              ),
            ),
            Container(
              child: Center(
                child: Wrap(
                  direction: Axis.horizontal,
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  runSpacing: 10,
                  children: [
                    ElevatedButton(
                      child: Text(
                        Platform.isMacOS ? "Show file in Finder" : "Show file in File Explorer",
                      ),
                      onPressed: () async {
                        if (_filePathFormKey.currentState.validate()) {
                          if (!await NativeFileExplorerLauncher.showFileInNativeFileExplorer(
                              _filePathController.text)) {
                            throw 'Could not open ${_filePathController.text}';
                          }
                        }
                      },
                    ),
                    SizedBox(
                      width: 25,
                    ),
                    ElevatedButton(
                      child: Text(
                        "Launch file",
                      ),
                      onPressed: () async {
                        if (_filePathFormKey.currentState.validate()) {
                          if (!await NativeFileExplorerLauncher.launchFile(_filePathController.text)) {
                            throw 'Could not launch ${_filePathController.text}';
                          }
                        }
                      },
                    ),
                    SizedBox(
                      width: 25,
                    ),
                    ElevatedButton(
                        key: _openWithButtonKey,
                        onPressed: () {
                          if (_filePathFormKey.currentState.validate()) {
                            _showPopupMenu();
                          }
                        },
                        child: Text("Launch file with"))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPopupMenu() async {
    final screenSize = MediaQuery.of(context).size;
    RenderBox box = _openWithButtonKey.currentContext.findRenderObject() as RenderBox;
    Offset position = box.localToGlobal(Offset.zero);
    double left = position.dx;
    double top = position.dy;
    double right = screenSize.width - position.dx - box.size.width;
    double bottom = screenSize.height - position.dy;

    final apps = await NativeFileExplorerLauncher.getSupportedApplications(_filePathController.text);
    final items = apps
        .map((e) => PopupMenuItem<AppMetadata>(
            onTap: () => NativeFileExplorerLauncher.launchFileWith(_filePathController.text, e.url),
            child: Column(children: [Image.memory(e.icon, width: 20, height: 20), SizedBox(width: 50), Text(e.name)]),
            value: e))
        .toList();

    await showMenu(context: context, position: RelativeRect.fromLTRB(left, top, right, bottom), items: items);
  }
}
