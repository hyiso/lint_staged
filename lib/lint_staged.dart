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
