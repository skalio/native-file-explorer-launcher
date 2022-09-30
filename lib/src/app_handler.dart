import 'dart:typed_data';
import 'package:meta/meta.dart';

// Described an specific application which can open a file
class AppHandler {
  String name;
  String url;
  Uint8List? icon;

  @internal
  AppHandler(this.name, this.url, {this.icon});
}
