import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_file_explorer_launcher/native_file_explorer_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

final GlobalKey<FormState> _filePathFormKey = GlobalKey();

class _MyAppState extends State<MyApp> {
  final TextEditingController _filePathController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
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
                          Platform.isMacOS
                              ? "Show file in Finder"
                              : "Show file in File Explorer",
                        ),
                        onPressed: () async {
                          if (_filePathFormKey.currentState.validate()) {
                            if (!await NativeFileExplorerLauncher
                                .showFileInNativeFileExplorer(
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
                            if (!await NativeFileExplorerLauncher.launchFile(
                                _filePathController.text)) {
                              throw 'Could not launch ${_filePathController.text}';
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
