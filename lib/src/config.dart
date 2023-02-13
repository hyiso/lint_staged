import 'dart:io';

import 'package:yaml/yaml.dart';

Future<Map<String, List<String>>?> loadConifg() async {
  final yaml = await loadYaml(File('pubspec.yaml').readAsStringSync());
  final config = yaml['lint_staged'] as Map?;
  return config?.cast<String, String>().map<String, List<String>>(
      (key, value) =>
          MapEntry(key, value.split('&&').map((e) => e.trim()).toList()));
}
