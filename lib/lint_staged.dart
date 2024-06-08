import 'dart:io';

import 'src/context.dart';
import 'src/logging.dart';
import 'src/message.dart';
import 'src/run.dart';
import 'src/symbols.dart';

///
/// Root lint_staged function that is called from `bin/lint_staged.dart`.
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
  int maxArgLength = 0,
  int? numOfProcesses,
}) async {
  try {
    final ctx = await runAll(
        allowEmpty: allowEmpty,
        diff: diff,
        diffFilter: diffFilter,
        stash: stash,
        maxArgLength: maxArgLength,
        workingDirectory: workingDirectory,
        numOfProcesses: numOfProcesses);
    _printTaskOutput(ctx);
    return true;
  } catch (e) {
    if (e is Context) {
      if (e.errors.contains(kConfigNotFoundError)) {
        stdout.error(kNoConfigurationMsg);
      } else if (e.errors.contains(kApplyEmptyCommitError)) {
        stdout.warn(kPreventedEmptyCommitMsg);
      } else if (e.errors.contains(kGitError) &&
          !e.errors.contains(kGetBackupStashError)) {
        stdout.failed(kGitErrorMsg);
        if (e.shouldBackup) {
          // No sense to show this if the backup stash itself is missing.
          stdout.error(kRestoreStashExampleMsg);
        }
      }
      _printTaskOutput(e);
      return false;
    }
    rethrow;
  }
}

void _printTaskOutput(Context ctx) {
  if (ctx.output.isEmpty) return;
  final log = ctx.errors.isNotEmpty ? stdout.failed : stdout.success;
  for (var line in ctx.output) {
    log(line);
  }
}
