import 'dart:io';

import 'package:glob/glob.dart';
import 'package:lint_staged/src/logger.dart';
import 'package:verbose/verbose.dart';

import 'chunk.dart';
import 'config.dart';
import 'exception.dart';
import 'git.dart';
import 'git_workflow.dart';
import 'lint_runner.dart';
import 'message.dart';
import 'context.dart';
import 'symbols.dart';

final logger = Logger('lint_staged:run');
final verbose = Verbose('lint_staged:run');

Future<LintStagedContext> runAll({
  bool allowEmpty = false,
  List<String> diff = const [],
  String? diffFilter,
  bool stash = true,
  String? workingDirectory,
  int maxArgLength = 0,
}) async {
  final ctx = getInitialContext();
  if (!FileSystemEntity.isDirectorySync('.git') &&
      !FileSystemEntity.isFileSync('.git')) {
    ctx.output.add(kNotGitRepoMsg);
    ctx.errors.add(kGitRepoError);
    throw createError(ctx, kNotGitRepoMsg);
  }

  /// Test whether we have any commits or not.
  /// Stashing must be disabled with no initial commit.
  final hasInitialCommit =
      await execGit(['log', '-1'], workingDirectory: workingDirectory)
          .then((s) => true)
          .catchError((s) => false);

  /// lint_staged will create a backup stash only when there's an initial commit,
  /// and when using the default list of staged files by default
  ctx.shouldBackup = hasInitialCommit && stash;
  if (!ctx.shouldBackup) {
    verbose(skippingBackupMsg(hasInitialCommit, diff));
  }
  final stagedFiles = await getStagedFiles(
    diff: diff,
    diffFilter: diffFilter,
    workingDirectory: workingDirectory,
  );
  if (stagedFiles == null) {
    ctx.output.add(kGetStagedFilesErrorMsg);
    ctx.errors.add(kGetStagedFilesError);
    throw createError(ctx, kNoStagedFilesMsg);
  }
  if (stagedFiles.isEmpty) {
    ctx.output.add(kNoStagedFilesMsg);
    return ctx;
  }
  verbose('Loaded list of staged files int git:\n$stagedFiles');

  final foundConfigs = await loadConifg(workingDirectory: workingDirectory);
  if (foundConfigs == null) {
    ctx.errors.add(kConfigNotFoundError);
    throw createError(ctx, kNoConfigurationMsg);
  }
  if (foundConfigs.isEmpty) {
    ctx.errors.add(kConfigEmptyError);
    return ctx;
  }
  verbose('Found configs: $foundConfigs');
  final matchedFiles = <String>{};
  final tasks = <Future Function()>[];
  for (var pattern in foundConfigs.keys) {
    final glob = Glob(pattern);
    final scopedFiles = <String>{};
    for (var file in stagedFiles) {
      verbose('$file matches $pattern is ${glob.matches(file)}');
      if (glob.matches(file)) {
        scopedFiles.add(file);
        matchedFiles.add(file);
      }
    }
    stagedFiles.removeWhere((file) => scopedFiles.contains(file));
    final runner = LintRunner(
        ctx: ctx,
        pattern: pattern,
        fileList: scopedFiles.toList(),
        scripts: foundConfigs[pattern]!,
        workingDirectory: workingDirectory);
    tasks.add(runner.run);
  }
  verbose('matched files: $matchedFiles');
  final matchedFileChunks =
      chunkFiles(matchedFiles.toList(), maxArgLength: maxArgLength);
  verbose('matched file chunks: $matchedFileChunks');
  final git = GitWorkflow(
    allowEmpty: allowEmpty,
    gitConfigDir: await getGitConfigDir(),
    diff: diff,
    diffFilter: diffFilter,
    matchedFileChunks: matchedFileChunks,
    workingDirectory: workingDirectory,
  );
  logger.stdout('Preparing lint_staged...');
  await git.prepare(ctx);
  if (ctx.hasPartiallyStagedFiles) {
    logger.stdout('Hiding unstaged changes to partially staged files...');
    await git.hideUnstagedChanges(ctx);
  }
  logger.stdout('Running tasks for staged files...');
  await Future.wait(tasks.map((task) => task()));
  if (!applyModifationsSkipped(ctx)) {
    logger.stdout('Applying modifications from tasks...');
    await git.applyModifications(ctx);
  }
  if (ctx.hasPartiallyStagedFiles && !restoreUnstagedChangesSkipped(ctx)) {
    logger.stdout('Restoring unstaged changes to partially staged files...');
    await git.resotreUnstagedChanges(ctx);
  }
  if (restoreOriginalStateEnabled(ctx) && !restoreOriginalStateSkipped(ctx)) {
    logger.stdout('Reverting to original state because of errors...');
    await git.restoreOriginState(ctx);
  }
  if (cleanupEnabled(ctx) && !cleanupSkipped(ctx)) {
    logger.stdout('Cleaning up temporary files...');
    await git.cleanup(ctx);
  }
  if (ctx.errors.isNotEmpty) {
    throw createError(ctx);
  }
  return ctx;
}
