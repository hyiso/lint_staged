import 'dart:io';

import 'package:path/path.dart';

class FileSystem {
  final String root;

  FileSystem([String? path]) : root = path ?? Directory.current.path;

  Future<void> append(String filename, String content) async {
    final file = File(join(root, filename));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    file.writeAsString(content, mode: FileMode.append);
  }

  Future<void> write(String filename, String content) async {
    final file = File(join(root, filename));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    file.writeAsString(content);
  }

  Future<void> remove(String filename) async {
    final file = File(join(root, filename));
    if (await file.exists()) {
      await file.delete(recursive: true);
    }
  }

  Future<bool> exists(String path) async {
    final file = File(join(root, path));
    if (await file.exists()) {
      return true;
    }
    return Directory(join(root, path)).exists();
  }

  Future<String?> read(String filename) async {
    final file = File(join(root, filename));
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }
}
