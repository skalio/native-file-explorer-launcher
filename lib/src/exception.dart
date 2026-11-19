import 'launcher.dart';

/// Why a [NativeFileExplorerLauncher] call failed.
enum FileLauncherError {
  /// There is nothing at the given path.
  fileNotFound,

  /// The requested app is gone, or no app is set up to open the file.
  applicationNotFound,

  /// The platform refused for another reason. See
  /// [FileLauncherException.message].
  failed,
}

/// Thrown when the platform could not show or open a file.
final class FileLauncherException implements Exception {
  /// Creates an exception for [error], with the platform's [message].
  const FileLauncherException(this.error, [this.message]);

  /// What went wrong.
  final FileLauncherError error;

  /// The platform's own description, meant for logs rather than users.
  final String? message;

  @override
  String toString() =>
      'FileLauncherException(${error.name}'
      '${message == null ? '' : ': $message'})';
}
