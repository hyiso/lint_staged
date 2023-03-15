import 'dart:io';

import 'logger.dart';
import 'package:path/path.dart';

final logger = Logger('lint_staged:git');

///
/// Get git diff arguments
///
List<String> getDiffArgs({
  List<String> diff = const [],
  String? diffFilter,
}) {
  ///
  /// Docs for --diff-filter option:
  /// @see https://git-scm.com/docs/git-diff#Documentation/git-diff.txt---diff-filterACDMRTUXB82308203
  ///
  final diffFilterArgs = diffFilter != null ? diffFilter.trim() : 'ACMR';

  /// Use `--diff branch1...branch2` or `--diff="branch1,branch2", or fall back to default staged files
  final diffArgs = diff.isNotEmpty ? diff : ['--staged'];

  /// Docs for -z option:
  /// @see https://git-scm.com/docs/git-diff#Documentation/git-diff.txt--z
  return [
    'diff',
    '--name-only',
    '-z',
    '--diff-filter=$diffFilterArgs',
    ...diffArgs
  ];
}

/// Explicitly never recurse commands into submodules, overriding local/global configuration.
/// @see https://git-scm.com/docs/git-config#Documentation/git-config.txt-submodulerecurse
///
const kNoSubmoduleRecurse = ['-c', 'submodule.recurse=false'];

///
/// Execute git command with [args] in given [workingDirectory].
///
Future<String> execGit(
  List<String> args, {
  String? workingDirectory,
}) async {
  final gitArgs = [...kNoSubmoduleRecurse, ...args];
  logger.debug('git ${gitArgs.join(' ')}');
  final result =
      await Process.run('git', gitArgs, workingDirectory: workingDirectory);
  if (result.exitCode != 0) {
    throw Exception(result.stderr);
  }
  String output = result.stdout as String;
  if (output.endsWith('\n')) {
    output = output.replaceFirst(RegExp(r'(\n)+$'), '');
  }
  return output;
}

///
/// Return array of strings split from the output of `git <something> -z`.
/// With `-z`, git prints `fileA\u0000fileB\u0000fileC\u0000` so we need to
/// remove the last occurrence of `\u0000` before splitting
///
List<String> parseGitZOutput(String input) {
  return input.isEmpty
      ? []
      : input.replaceFirst(RegExp(r'\u0000$'), '').split('\u0000');
}

Future<List<String>?> getStagedFiles({
  List<String> diff = const [],
  String? diffFilter,
  String? workingDirectory,
}) async {
  final output = await execGit(getDiffArgs(diff: diff, diffFilter: diffFilter),
      workingDirectory: workingDirectory);
  return parseGitZOutput(output).map((e) => normalize(e)).toList();
}

Future<String> getGitConfigDir() async {
  return await execGit(['rev-parse', '--git-dir']);
}
