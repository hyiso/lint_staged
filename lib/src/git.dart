import 'dart:io';

import 'package:path/path.dart';

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
  final result = await Process.run('git', [...kNoSubmoduleRecurse, ...args],
      workingDirectory: workingDirectory);
  return result.stdout as String;
}

///
/// Return array of strings split from the output of `git <something> -z`.
/// With `-z`, git prints `fileA\u0000fileB\u0000fileC\u0000` so we need to
/// remove the last occurrence of `\u0000` before splitting
///
List<String> parseGitZOutput(String input) {
  return input.isEmpty ? [] : input.replaceAll(r'\u0000$', '').split('\u0000');
}

Future<Iterable<String>?> getStagedFiles({
  List<String> diff = const [],
  String? diffFilter,
  String? workingDirectory,
}) async {
  final output = await execGit(getDiffArgs(diff: diff, diffFilter: diffFilter),
      workingDirectory: workingDirectory);
  return parseGitZOutput(output).map((e) => normalize(e));
}
