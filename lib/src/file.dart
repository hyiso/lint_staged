import 'dart:io';
import 'dart:typed_data';

///
/// Read contents of a file to buffer
///
Future<Uint8List?> readFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    return file.readAsBytes();
  }
  return null;
}

Future<void> unlink(String filename) async {
  final file = File(filename);
  await file.delete();
}

///
/// Write buffer to file
///
Future<void> writeFile(String path, Uint8List bytes) async {
  final file = File(path);
  if (!await file.exists()) {
    await file.create(recursive: true);
  }
  file.writeAsBytes(bytes);
}
