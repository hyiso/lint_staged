import 'dart:io';

import 'package:verbose/verbose.dart';

import 'src/context.dart';
import 'src/exception.dart';
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
}) async {
  try {
    final spinner = Spinner();
    final ctx = await runAll(
        allowEmpty: allowEmpty,
        diff: diff,
        diffFilter: diffFilter,
        stash: stash,
        maxArgLength: maxArgLength,
        workingDirectory: workingDirectory,
        spinner: spinner);
    _printTaskOutput(ctx);
    return true;
  } catch (e) {
    final verbose = Verbose('lint_staged');
    if (e is LintStagedException && e.ctx.errors.isNotEmpty) {
      if (e.ctx.errors.contains(kConfigNotFoundError)) {
        verbose(kNoConfigurationMsg);
      } else if (e.ctx.errors.contains(kApplyEmptyCommitError)) {
        verbose(kPreventedEmptyCommitMsg);
      } else if (e.ctx.errors.contains(kGitError) &&
          !e.ctx.errors.contains(kGetBackupStashError)) {
        verbose(kGitErrorMsg);
        if (e.ctx.shouldBackup) {
          // No sense to show this if the backup stash itself is missing.
          verbose(kRestoreStashExampleMsg);
        }
      }
      _printTaskOutput(e.ctx);
    }
    return false;
  }
}

void _printTaskOutput(LintStagedContext ctx) {
  if (ctx.output.isEmpty) return;
  final log = ctx.errors.isNotEmpty ? stderr.failed : stdout.success;
  for (var line in ctx.output) {
    log(line);
  }
}
