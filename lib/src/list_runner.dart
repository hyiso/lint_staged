import 'dart:io';

import 'package:lint_staged/src/context.dart';
import 'package:lint_staged/src/symbols.dart';

import 'logger.dart';

///
/// `dart fix` for single file is supportted in Dart SDK 2.18
/// When running lower than 2.18, fix single file will failed.
///
/// Addint this to enable script to run on file parent.
///
/// eg. `dart fix --apply <file>/../` will resolve `<file>/../` to parent path of the file.
///
const _kFilePlaceholder = '<file>';

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
    final resolvedPaths = <String, Set<String>>{};
    await Future.wait(scripts.map((script) async {
      final args = script.split(' ');
      int index = args.length;
      for (var i = args.length - 1; i >= 0; i--) {
        if (args[i].contains(_kFilePlaceholder)) {
          index = i;
          break;
        }
      }
      for (var file in matchedFiles) {
        final cmds = [...args];
        if (index != args.length) {
          final path =
              resolvePath(args[index].replaceFirst(_kFilePlaceholder, file));
          if (resolvedPaths[script] == null ||
              !resolvedPaths[script]!.contains(path)) {
            cmds[index] = path;
          } else {
            continue;
          }
        } else {
          cmds.add(file);
        }
        logger.trace(cmds.join(' '));
        final result = await Process.run(cmds.removeAt(0), cmds,
            workingDirectory: workingDirectory);
        if (result.exitCode != 0) {
          ctx.errors.add(kTaskError);
        }
      }
    }));
  }
}

String resolvePath(String path) {
  final parts = path.split(Platform.pathSeparator);
  final stack = <String>[];
  for (var part in parts) {
    if (part == '.') {
      continue;
    }
    if (part == '..') {
      stack.removeLast();
      continue;
    }
    stack.add(part);
  }
  return stack.join(Platform.pathSeparator);
}
