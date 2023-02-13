import 'dart:io';

import 'package:lint_staged/src/config.dart';
import 'package:lint_staged/src/linter.dart';

import 'chunk.dart';
import 'git.dart';
import 'git_workflow.dart';
import 'logger.dart';
import 'message.dart';
import 'state.dart';
import 'symbols.dart';

Future<LintState> runAll({
  bool allowEmpty = false,
  List<String> diff = const [],
  String? diffFilter,
  bool stash = true,
  String? workingDirectory,
}) async {
  final ctx = getInitialState();
  if (!FileSystemEntity.isDirectorySync('.git') &&
      !FileSystemEntity.isFileSync('.git')) {
    ctx.output.add('Current directory is not a git directory!');
    ctx.errors.add(kGitRepoError);
    return ctx;
  }

  /// Test whether we have any commits or not.
  /// Stashing must be disabled with no initial commit.
  final hasInitialCommit =
      await execGit(['log', '-1']).then((s) => true).catchError((s) => false);

  /// Lint-staged will create a backup stash only when there's an initial commit,
  /// and when using the default list of staged files by default
  ctx.shouldBackup = hasInitialCommit && stash;
  if (!ctx.shouldBackup) {
    logger.trace(skippingBackup(hasInitialCommit, diff));
  }
  final files = await getStagedFiles(
    diff: diff,
    diffFilter: diffFilter,
    workingDirectory: workingDirectory,
  );
  if (files == null) {
    ctx.output.add('Failed to get staged files!');
    ctx.errors.add(kGetStagedFilesError);
    return ctx;
  }
  if (files.isEmpty) {
    ctx.output.add('No staged files');
    return ctx;
  }
  final stagedFileChunks = chunkFiles(files: files);
  if (stagedFileChunks.length > 1) {
    logger.stdout('Chunked staged files into ${stagedFileChunks.length} part');
  }

  final foundConfigs = await loadConifg();
  if (foundConfigs == null || foundConfigs.isEmpty) {
    ctx.errors.add(kConfigNotFoundError);
    return ctx;
  }
  if (foundConfigs.isEmpty) {
    ctx.errors.add(kConfigEmptyError);
    return ctx;
  }

  final matchedFiles = files.where((file) => file.endsWith('.dart')).toList();
  final linter =
      Linter(matchedFiles: matchedFiles, scripts: foundConfigs['.dart'] ?? []);
  final matchedFileChunks = chunkFiles(files: matchedFiles);
  final git = GitWorkflow(
    allowEmpty: allowEmpty,
    gitConfigDir: await getGitConfigDir(),
    diff: diff,
    diffFilter: diffFilter,
    matchedFileChunks: matchedFileChunks,
  );
  logger.stdout('Preparing lint_staged...');
  await git.prepare(ctx);
  if (ctx.hasPartiallyStagedFiles) {
    logger.stdout('Hiding unstaged changes to partially staged files...');
    await git.hideUnstagedChanges(ctx);
  }
  logger.stdout('Running tasks for staged files...');
  await linter.run();
  if (!ctx.applyModifationsSkipped) {
    logger.stdout('Applying modifications from tasks...');
    await git.applyModifications(ctx);
  }
  if (ctx.hasPartiallyStagedFiles && !ctx.restoreUnstagedChangesSkipped) {
    logger.stdout('Restoring unstaged changes to partially staged files...');
    await git.resotreUnstagedChanges(ctx);
  }
  if (ctx.restoreOriginalStateEnabled && !ctx.restoreOriginalStateSkipped) {
    logger.stdout('Reverting to original state because of errors...');
    await git.restoreOriginState(ctx);
  }
  if (ctx.cleanupEnabled && !ctx.cleanupSkipped) {
    logger.stdout('Cleaning up temporary files...');
    await git.cleanup(ctx);
  }
  return ctx;
}
