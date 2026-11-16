import 'dart:typed_data';
import 'local_file_store_native.dart'
    if (dart.library.html) 'local_file_store_web.dart'
    as platform;

abstract final class LocalFileStore {
  static Future<void> save(String relativePath, List<int> bytes) {
    _validate(relativePath);
    return platform.save(relativePath, bytes);
  }

  static Future<Uint8List?> read(String relativePath) {
    _validate(relativePath);
    return platform.read(relativePath);
  }

  static Future<void> remove(String relativePath) {
    _validate(relativePath);
    return platform.remove(relativePath);
  }

  static Future<void> writePickedFile(String path, List<int> bytes) =>
      platform.writePickedFile(path, bytes);

  static void _validate(String path) {
    final parts = path.split('/');
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains(':') ||
        path.contains(r'\') ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw FormatException('Invalid app-relative file path: $path');
    }
  }
}
