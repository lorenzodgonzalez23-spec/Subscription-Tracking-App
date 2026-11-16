import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> saveExportFile({
  required String fileName,
  required String extension,
  required String mimeType,
  required Uint8List bytes,
}) async {
  final mobile = Platform.isAndroid || Platform.isIOS;
  final path = await FilePicker.platform.saveFile(
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: [extension],
    bytes: mobile ? bytes : null,
  );
  if (path == null || mobile) return;
  await File(path).writeAsBytes(bytes, flush: true);
}
