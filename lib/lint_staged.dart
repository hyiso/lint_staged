import 'dart:io';

import 'package:cli_util/cli_logging.dart';

import 'src/logger.dart';
import 'src/run.dart';
import 'src/state.dart';

///
/// Root lint-staged function that is called from `bin/lint_staged.dart`.
///
/// [allowEmpty] - Allow empty commits when tasks revert all staged changes
/// [diff] - Override the default "--staged" flag of "git diff" to get list of files
/// [diffFilter] - Override the default "--diff-filter=ACMR" flag of "git diff" to get list of files
/// [stash] - Enable the backup stash, and revert in case of errors
///
Future<bool> lintStaged({
  bool allowEmpty = false,
  List<String> diff = const [],
  String? diffFilter,
  bool stash = true,
  String? workingDirectory,
}) async {
  try {
    final ctx = await runAll(
        allowEmpty: allowEmpty,
        diff: diff,
        diffFilter: diffFilter,
        stash: stash,
        maxArgLength: _maxArgLength ~/ 2,
        workingDirectory: workingDirectory);
    printTaskOutput(ctx, logger);
    return true;
    // ignore: empty_catches
  } catch (e) {}
  return false;
}

void printTaskOutput(LintState ctx, Logger logger) {
  if (ctx.output.isEmpty) return;
  final log = ctx.errors.isNotEmpty ? logger.stderr : logger.stdout;
  for (var line in ctx.output) {
    log(line);
  }
}

///
/// Get the maximum length of a command-line argument string based on current platform
///
/// https://serverfault.com/questions/69430/what-is-the-maximum-length-of-a-command-line-in-mac-os-x
/// https://support.microsoft.com/en-us/help/830473/command-prompt-cmd-exe-command-line-string-limitation
/// https://unix.stackexchange.com/a/120652
///
int get _maxArgLength {
  if (Platform.isMacOS) {
    return 262144;
  }
  return 131072;
}
