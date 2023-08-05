import 'dart:io';

import 'package:path/path.dart';

class FileSystem {
  final String path;

  FileSystem([String? path]) : path = path ?? Directory.current.path;

  Future<void> appendFile(String filename, String content) async {
    final file = File(join(path, filename));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    file.writeAsString(content, mode: FileMode.append);
  }

  Future<void> writeFile(String filename, String content) async {
    final file = File(join(path, filename));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    file.writeAsString(content);
  }

  Future<void> removeFile(String filename) async {
    final file = File(join(path, filename));
    if (await file.exists()) {
      await file.delete(recursive: true);
    }
  }

  Future<bool> existsFile(String filename) =>
      File(join(path, filename)).exists();

  Future<String?> readFile(String filename) async {
    final file = File(join(path, filename));
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }
}
