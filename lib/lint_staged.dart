import 'dart:io';

import 'package:lint_staged/src/chunk.dart';
import 'package:lint_staged/src/git_workflow.dart';
import 'package:lint_staged/src/logger.dart';
import 'package:lint_staged/src/state.dart';
import 'package:lint_staged/src/symbols.dart';
import 'package:yaml/yaml.dart';

import 'src/git.dart';
import 'src/message.dart';

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
  final ctx = getInitialState();
  if (!FileSystemEntity.isDirectorySync('.git') &&
      !FileSystemEntity.isFileSync('.git')) {
    ctx.output.add('Current directory is not a git directory!');
    ctx.errors.add(kGitRepoError);
    return false;
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
    return false;
  }
  if (files.isEmpty) {
    logger.stdout('No staged files');
    return true;
  }
  final stagedFileChunks = chunkFiles(files: files);
  if (stagedFileChunks.length > 1) {
    logger.stdout('Chunked staged files into ${stagedFileChunks.length} part');
  }

  final yaml = await loadYaml(File('pubspec.yaml').readAsStringSync());
  final config = yaml['lint_staged'];
  final dartLinters = config['.dart'];
  late Future<ProcessResult?> Function(String file) dartCommands;
  if (dartLinters == null) {
    logger.stdout('No linters for .dart files');
  } else if (dartLinters is String) {
    final commands = dartLinters.split('&&').map((e) => e.trim().split(' '));
    dartCommands = (file) =>
        runCommands(commands, file, workingDirectory: workingDirectory);
  } else if (dartLinters is List) {
    final commands = dartLinters.cast<String>().map((e) => e.trim().split(' '));
    dartCommands = (file) =>
        runCommands(commands, file, workingDirectory: workingDirectory);
  }

  final matchedFiles = files.where((file) => file.endsWith('.dart')).toList();
  final matchedFileChunks = chunkFiles(files: matchedFiles);
  final git = GitWorkflow(
    allowEmpty: allowEmpty,
    gitConfigDir: await getGitConfigDir(),
    diff: diff,
    diffFilter: diffFilter,
    matchedFileChunks: matchedFileChunks,
  );
  logger.stdout('Preparing lint_staged...');
  final hasPartiallyStagedFiles = await git.prepare();
  if (hasPartiallyStagedFiles) {
    logger.stdout('Hiding unstaged changes to partially staged files...');
    await git.hideUnstagedChanges();
  }
  logger.stdout('Running tasks for staged files...');
  final tasks = <Future<ProcessResult?>>[];
  for (var file in matchedFiles) {
    tasks.add(dartCommands(file));
  }
  final results = (await Future.wait(tasks));
  if (!results.every((result) => result == null || result.exitCode == 0)) {
    return false;
  }
  logger.stdout('Applying modifications from tasks...');
  await git.applyModifications();
  if (hasPartiallyStagedFiles) {
    logger.stdout('Restoring unstaged changes to partially staged files...');
    await git.resotreUnstagedChanges();
  }
  // logger.stdout('Reverting to original state because of errors...');
  // await git.restoreOriginState();
  // logger.stdout('Cleaning up temporary files...');
  // await git.cleanup();
  return true;
}

Future<ProcessResult?> runCommands(
  Iterable<List<String>> commands,
  String file, {
  String? workingDirectory,
}) async {
  ProcessResult? result;
  for (var command in commands) {
    logger.stdout('${command.join(' ')} $file');
    final res = await Process.run(command.removeAt(0), [...command, file],
        workingDirectory: workingDirectory);
    result = res + result;
  }
  return result;
}

extension _ProcessResult on ProcessResult {
  ProcessResult operator +(ProcessResult? other) {
    if (other == null) {
      return this;
    }
    return ProcessResult(0, exitCode + other.exitCode,
        '$stdout\n${other.stdout}', '$stdout\n${other.stdout}');
  }
}
