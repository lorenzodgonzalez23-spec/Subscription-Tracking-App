import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> _file(String relativePath) async {
  final documents = await getApplicationDocumentsDirectory();
  return File(p.joinAll([documents.path, ...relativePath.split('/')]));
}

Future<void> save(String relativePath, List<int> bytes) async {
  final file = await _file(relativePath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<Uint8List?> read(String relativePath) async {
  final file = await _file(relativePath);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<void> remove(String relativePath) async {
  final file = await _file(relativePath);
  if (await file.exists()) await file.delete();
}

Future<void> writePickedFile(String path, List<int> bytes) async {
  await File(path).writeAsBytes(bytes, flush: true);
}
