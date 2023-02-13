import 'dart:io';

import 'logger.dart';

class Task {
  List<String> scripts;

  String path;

  Task(this.scripts, this.path);

  Future<ProcessResult?> run() async {
    ProcessResult? result;
    for (var script in scripts) {
      final command = script.split(' ');
      logger.stdout('${command.join(' ')} $path');
      final res = await Process.run(command.removeAt(0), [...command, path]);
      result = res + result;
    }
    return result;
  }
}

extension _ProcessResult on ProcessResult {
  ProcessResult operator +(ProcessResult? other) {
    if (other == null) {
      return this;
    }
    return ProcessResult(0, exitCode + other.exitCode,
        '$stdout\n${other.stdout}', '$stdout\n${other.stdout}');
  }
}

class Linter {
  List<String> matchedFiles;
  List<String> scripts;
  List<Task> tasks;
  Linter({
    required this.matchedFiles,
    required this.scripts,
  }) : tasks = matchedFiles.map((file) => Task(scripts, file)).toList();

  Future<void> run() async {
    await Future.wait(tasks.map((task) => task.run()));
  }
}
