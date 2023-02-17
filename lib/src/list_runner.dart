import 'dart:io';

import 'package:lint_staged/src/context.dart';
import 'package:lint_staged/src/symbols.dart';

import 'logger.dart';

class ListRunner {
  List<String> matchedFiles;
  List<String> scripts;
  String? workingDirectory;
  LintStagedContext ctx;

  ListRunner({
    required this.matchedFiles,
    required this.scripts,
    required this.ctx,
    this.workingDirectory,
  });

  Future<void> run() async {
    await Future.wait(matchedFiles.map((file) async {
      for (var script in scripts) {
        final command = script.split(' ');
        logger.trace('${command.join(' ')} $file');
        final result = await Process.run(
            command.removeAt(0), [...command, file],
            workingDirectory: workingDirectory);
        if (result.exitCode != 0) {
          ctx.errors.add(kTaskError);
        }
      }
    }));
  }
}
