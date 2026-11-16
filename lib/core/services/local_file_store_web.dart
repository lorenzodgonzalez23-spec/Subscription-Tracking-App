import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

String _key(String path) => 'subglass_file_$path';

Future<void> save(String relativePath, List<int> bytes) async {
  final preferences = await SharedPreferences.getInstance();
  final saved = await preferences.setString(
    _key(relativePath),
    base64Encode(bytes),
  );
  if (!saved) throw StateError('Could not persist app file $relativePath');
}

Future<Uint8List?> read(String relativePath) async {
  final preferences = await SharedPreferences.getInstance();
  final encoded = preferences.getString(_key(relativePath));
  return encoded == null ? null : Uint8List.fromList(base64Decode(encoded));
}

Future<void> remove(String relativePath) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.remove(_key(relativePath));
}

Future<void> writePickedFile(String path, List<int> bytes) async {
  throw UnsupportedError(
    'The browser handles downloads directly; it does not expose a writable path.',
  );
}
