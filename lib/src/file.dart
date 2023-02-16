import 'dart:io';

import 'package:path/path.dart';

Future<void> appendFile(
  String filename,
  String content, {
  String? workingDirectory,
}) async {
  final file = File(join(workingDirectory ?? Directory.current.path, filename));
  if (!await file.exists()) {
    await file.create(recursive: true);
  }
  file.writeAsString(content, mode: FileMode.append);
}

Future<void> writeFile(
  String filename,
  String content, {
  String? workingDirectory,
}) async {
  final file = File(join(workingDirectory ?? Directory.current.path, filename));
  if (!await file.exists()) {
    await file.create(recursive: true);
  }
  file.writeAsString(content);
}

Future<void> removeFile(
  String filename, {
  String? workingDirectory,
}) async {
  final file = File(join(workingDirectory ?? Directory.current.path, filename));
  await file.delete(recursive: true);
}

Future<String?> readFile(
  String filename, {
  String? workingDirectory,
}) async {
  final file = File(join(workingDirectory ?? Directory.current.path, filename));
  if (await file.exists()) {
    return await file.readAsString();
  }
  return null;
}
