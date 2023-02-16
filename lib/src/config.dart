import 'dart:io';

import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

Future<Map<String, List<String>>?> loadConifg({
  String? workingDirectory,
}) async {
  final pubspecPath =
      join(workingDirectory ?? Directory.current.path, 'pubspec.yaml');
  final yaml = await loadYaml(File(pubspecPath).readAsStringSync());
  final config = yaml['lint_staged'] as Map?;
  return config?.cast<String, String>().map<String, List<String>>(
      (key, value) =>
          MapEntry(key, value.split('&&').map((e) => e.trim()).toList()));
}
