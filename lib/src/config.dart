import 'dart:io';

import 'package:path/path.dart';
import 'package:verbose/verbose.dart';
import 'package:yaml/yaml.dart';

final _verbose = Verbose('lint_staged:config');

Future<Map<String, List<String>>?> loadConfig({
  String? workingDirectory,
}) async {
  final pubspecPath =
      join(workingDirectory ?? Directory.current.path, 'pubspec.yaml');
  final yaml = await loadYaml(File(pubspecPath).readAsStringSync());
  final map = yaml['lint_staged'];
  if (map is! Map) {
    return null;
  }
  _verbose('Found config: $map');
  final config = <String, List<String>>{};
  for (var entry in map.entries) {
    final value = entry.value;
    if (value is String) {
      config[entry.key] = value.split('&&').map((e) => e.trim()).toList();
    } else if (value is List) {
      config[entry.key] = value.cast();
    }
  }
  return config;
}
