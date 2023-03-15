import 'src/context.dart';
import 'src/exception.dart';
import 'src/logger.dart';
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
  final logger = Logger('lint_staged');
  try {
    final ctx = await runAll(
        allowEmpty: allowEmpty,
        diff: diff,
        diffFilter: diffFilter,
        stash: stash,
        maxArgLength: maxArgLength,
        workingDirectory: workingDirectory);
    _printTaskOutput(ctx, logger);
    return true;
    // ignore: empty_catches
  } catch (e) {
    if (e is LintStagedException && e.ctx.errors.isNotEmpty) {
      if (e.ctx.errors.contains(kConfigNotFoundError)) {
        logger.debug(kNoConfigurationMsg);
      } else if (e.ctx.errors.contains(kApplyEmptyCommitError)) {
        logger.debug(kPreventedEmptyCommitMsg);
      } else if (e.ctx.errors.contains(kGitError) &&
          !e.ctx.errors.contains(kGetBackupStashError)) {
        logger.debug(kGitErrorMsg);
        if (e.ctx.shouldBackup) {
          // No sense to show this if the backup stash itself is missing.
          logger.debug(kRestoreStashExampleMsg);
        }
      }

      _printTaskOutput(e.ctx, logger);
      return false;
    }
    rethrow;
  }
}

void _printTaskOutput(LintStagedContext ctx, Logger logger) {
  if (ctx.output.isEmpty) return;
  final log = ctx.errors.isNotEmpty ? logger.stderr : logger.stdout;
  for (var line in ctx.output) {
    log(line);
  }
}
