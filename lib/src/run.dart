import 'dart:io';

import 'package:lint_staged/src/fs.dart';
import 'package:verbose/verbose.dart';

import 'chunk.dart';
import 'config.dart';
import 'exception.dart';
import 'git.dart';
import 'group.dart';
import 'workflow.dart';
import 'logging.dart';
import 'message.dart';
import 'context.dart';
import 'symbols.dart';

final _verbose = Verbose('lint_staged:run');

Future<LintStagedContext> runAll({
  bool allowEmpty = false,
  required List<String> diff,
  String? diffFilter,
  bool stash = true,
  String? workingDirectory,
  int maxArgLength = 0,
  required Spinner spinner,
}) async {
  final ctx = getInitialContext();
  if (!FileSystemEntity.isDirectorySync('.git') &&
      !FileSystemEntity.isFileSync('.git')) {
    ctx.output.add(kNotGitRepoMsg);
    ctx.errors.add(kGitRepoError);
    throw createError(ctx, kNotGitRepoMsg);
  }
  final git = Git(
      diff: diff, diffFilter: diffFilter, workingDirectory: workingDirectory);
  final fs = FileSystem(workingDirectory);

  /// Test whether we have any commits or not.
  /// Stashing must be disabled with no initial commit.
  final hasInitialCommit = await git.hasInitialCommit;

  /// lint_staged will create a backup stash only when there's an initial commit,
  /// and when using the default list of staged files by default
  ctx.shouldBackup = hasInitialCommit && stash;
  if (!ctx.shouldBackup) {
    stderr.warn(skippingBackupMsg(hasInitialCommit, diff));
  }
  final stagedFiles = await git.stagedFiles;
  if (stagedFiles.isEmpty) {
    ctx.output.add(kNoStagedFilesMsg);
    return ctx;
  }
  final config = await loadConfig(workingDirectory: workingDirectory);
  if (config == null || config.isEmpty) {
    ctx.errors.add(kConfigNotFoundError);
    throw createError(ctx, kNoConfigurationMsg);
  }
  final groups = groupFilesByConfig(config: config, files: stagedFiles);
  if (groups.isEmpty) {
    _verbose(kNoStagedFilesMatchedMsg);
    return ctx;
  }
  final matchedFiles =
      groups.values.expand((element) => element.files).toList();
  final matchedFileChunks =
      chunkFiles(matchedFiles, maxArgLength: maxArgLength);
  final workflow = Workflow(
    fs: fs,
    git: git,
    allowEmpty: allowEmpty,
    matchedFileChunks: matchedFileChunks,
  );
  spinner.progress('Preparing lint_staged...');
  await workflow.prepare(ctx);
  spinner.success('Prepared lint_staged');
  if (ctx.hasPartiallyStagedFiles) {
    spinner.progress('Hiding unstaged changes to partially staged files...');
    await workflow.hideUnstagedChanges(ctx);
    spinner.success('Hide unstaged changes to partially staged files');
  }
  spinner.progress('Running tasks for staged files...');
  await Future.wait(groups.values.map((group) async {
    await Future.wait(group.scripts.map((script) async {
      final args = script.split(' ');
      final exe = args.removeAt(0);
      await Future.wait(group.files.map((file) async {
        final result = await Process.run(exe, [...args, file],
            workingDirectory: workingDirectory);
        final messsages = ['$script $file'];
        if (result.stderr.toString().trim().isNotEmpty) {
          messsages.add(result.stderr.toString().trim());
        }
        if (result.stdout.toString().trim().isNotEmpty) {
          messsages.add(result.stdout.toString().trim());
        }
        _verbose(messsages.join('\n'));
        if (result.exitCode != 0) {
          ctx.output.add(messsages.join('\n'));
          ctx.errors.add(kTaskError);
        }
      }));
    }));
  }));
  spinner.success('Running tasks for staged files');
  if (!applyModifationsSkipped(ctx)) {
    spinner.progress('Applying modifications from tasks...');
    await workflow.applyModifications(ctx);
    spinner.success('Applied modifications from tasks');
  }
  if (ctx.hasPartiallyStagedFiles && !restoreUnstagedChangesSkipped(ctx)) {
    spinner.progress('Restoring unstaged changes to partially staged files...');
    await workflow.resotreUnstagedChanges(ctx);
    spinner.success('Restored unstaged changes to partially staged files');
  }
  if (restoreOriginalStateEnabled(ctx) && !restoreOriginalStateSkipped(ctx)) {
    spinner.progress('Reverting to original state because of errors...');
    await workflow.restoreOriginState(ctx);
    spinner.success('Reverted to original state because of errors');
  }
  if (cleanupEnabled(ctx) && !cleanupSkipped(ctx)) {
    spinner.progress('Cleaning up temporary files...');
    await workflow.cleanup(ctx);
    spinner.success('Cleaned up temporary files');
  }
  if (ctx.errors.isNotEmpty) {
    throw createError(ctx);
  }
  return ctx;
}
