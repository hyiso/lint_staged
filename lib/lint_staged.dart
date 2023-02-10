import 'dart:io';

import 'package:lint_staged/src/git_workflow.dart';
import 'package:lint_staged/src/logger.dart';
import 'package:yaml/yaml.dart';

import 'src/git.dart';

Future<bool> lintStaged({
  bool allowEmpty = false,
  List<String> diff = const [],
  String? diffFilter,
  bool stash = true,
  String? workingDirectory,
}) async {
  final partiallyStagedFiles = await GitWorkflow().getPartiallyStagedFiles();
  print(partiallyStagedFiles);
  return true;
  final files = await getStagedFiles(
    diff: diff,
    diffFilter: diffFilter,
    workingDirectory: workingDirectory,
  );
  if (files == null) {
    logger.stdout('Failed to get staged files');
    return false;
  }
  if (files.isEmpty) {
    logger.stdout('No staged files');
    return true;
  }

  final yaml = await loadYaml(File('pubspec.yaml').readAsStringSync());
  final config = yaml['lint_staged'];
  final dartLinters = config['.dart'];
  late Future<ProcessResult?> Function(String file) dartCommands;
  if (dartLinters == null) {
    logger.stdout('No linters for .dart files');
  } else if (dartLinters is String) {
    final commands = dartLinters.split('&&').map((e) => e.trim().split(' '));
    dartCommands = (file) =>
        runCommands(commands, file, workingDirectory: workingDirectory);
  } else if (dartLinters is List) {
    final commands = dartLinters.cast<String>().map((e) => e.trim().split(' '));
    dartCommands = (file) =>
        runCommands(commands, file, workingDirectory: workingDirectory);
  }

  final dartFiles = files.where((file) => file.endsWith('.dart'));
  final tasks = <Future<ProcessResult?>>[];
  for (var file in dartFiles) {
    tasks.add(dartCommands(file));
  }
  final results = (await Future.wait(tasks));
  return results.every((result) => result == null || result.exitCode == 0);
}

Future<ProcessResult?> runCommands(
  Iterable<List<String>> commands,
  String file, {
  String? workingDirectory,
}) async {
  ProcessResult? result;
  for (var command in commands) {
    logger.stderr('${command.join(' ')} $file');
    final res = await Process.run(command.removeAt(0), [...command, file],
        workingDirectory: workingDirectory);
    result = res + result;
  }
  return result;
}

extension _ProcessResult on ProcessResult {
  ProcessResult operator +(ProcessResult? other) {
    if (other == null) {
      return this;
    }
    return ProcessResult(0, exitCode + other.exitCode,
        '$stdout\n${other.stdout}', '$stderr\n${other.stderr}');
  }
}
