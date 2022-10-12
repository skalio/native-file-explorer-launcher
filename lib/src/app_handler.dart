import 'dart:typed_data';
import 'package:meta/meta.dart';

/// Described an specific application which can open a file
@immutable
class AppHandler {
  /// The display name of the application
  final String name;

  /// The path to the application
  final String url;

  /// An byte buffer which represents the icon of the application
  final Uint8List? icon;

  @internal
  AppHandler({required this.name, required this.url, this.icon});
}
