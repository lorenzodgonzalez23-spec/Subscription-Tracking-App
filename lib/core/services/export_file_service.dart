import 'dart:typed_data';
import 'export_file_service_native.dart'
    if (dart.library.js_interop) 'export_file_service_web.dart'
    as platform;

Future<void> saveExportFile({
  required String fileName,
  required String extension,
  required String mimeType,
  required Uint8List bytes,
}) => platform.saveExportFile(
  fileName: fileName,
  extension: extension,
  mimeType: mimeType,
  bytes: bytes,
);
