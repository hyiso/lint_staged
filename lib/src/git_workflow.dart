import 'dart:io';
import 'dart:math';
import 'package:lint_staged/src/logger.dart';
import 'package:lint_staged/src/symbols.dart';
import 'package:path/path.dart';

import 'file.dart';
import 'git.dart';
import 'context.dart';

/// In git status machine output, renames are presented as `to`NUL`from`
/// When diffing, both need to be taken into account, but in some cases on the `to`.
final _renameRegex = RegExp(r'\x00');

final logger = Logger('lint_staged:GitWorkflow');

///
/// From list of files, split renames and flatten into two files `to`NUL`from`.
///
List<String> processRenames(List<String> files,
    [bool includeRenameFrom = true]) {
  return files.fold([], (flattened, file) {
    if (_renameRegex.hasMatch(file)) {
      /// first is to, last is from
      final rename = file.split(_renameRegex);
      if (includeRenameFrom) {
        flattened.add(rename.last);
      }
      flattened.add(rename.first);
    } else {
      flattened.add(file);
    }
    return flattened;
  });
}

const kStash = 'lint_staged automatic backup';

const kMergeHead = 'MERGE_HEAD';
const kMergeMode = 'MERGE_MODE';
const kMergeMsg = 'MERGE_MSG';

const kPatchUnstaged = 'lint_staged_unstaged.path';

const kGitDiffArgs = [
  '--binary', // support binary files
  '--unified=0', // do not add lines around diff for consistent behaviour
  '--no-color', // disable colors for consistent behaviour
  '--no-ext-diff', // disable external diff tools for consistent behaviour
  '--src-prefix=a/', // force prefix for consistent behaviour
  '--dst-prefix=b/', // force prefix for consistent behaviour
  '--patch', // output a patch that can be applied
  '--submodule=short', // always use the default short format for submodules
];
const kGitApplyArgs = [
  '-v',
  '--whitespace=nowarn',
  '--recount',
  '--unidiff-zero'
];

class GitWorkflow {
  final bool allowEmpty;
  final String gitConfigDir;
  final String? diffFilter;
  final List<String> diff;
  final List<List<String>> matchedFileChunks;

  late List<String> partiallyStagedFiles;
  late List<String> deletedFiles;

  String? workingDirectory;

  ///
  /// These three files hold state about an ongoing git merge
  /// Resolve paths during constructor
  ///
  final String mergeHeadFilename;
  final String mergeModeFilename;
  final String mergeMsgFilename;

  String? mergeHeadContent;
  String? mergeModeContent;
  String? mergeMsgContent;

  GitWorkflow({
    this.allowEmpty = false,
    this.gitConfigDir = '.git',
    this.diff = const [],
    this.diffFilter,
    this.matchedFileChunks = const [],
    this.workingDirectory,
  })  : mergeHeadFilename = join(gitConfigDir, kMergeHead),
        mergeModeFilename = join(gitConfigDir, kMergeMode),
        mergeMsgFilename = join(gitConfigDir, kMergeMsg);

  ///
  /// Get absolute path to file hidden inside .git
  /// @param {string} filename
  ///
  String getHiddenFilepath(filename) {
    return join(gitConfigDir, filename);
  }

  ///
  /// Get name of backup stash
  ///
  Future<String> getBackupStash(LintStagedContext ctx) async {
    final stashes =
        await execGit(['stash', 'list'], workingDirectory: workingDirectory);
    final index =
        stashes.split('\n').indexWhere((line) => line.contains(kStash));
    if (index == -1) {
      ctx.errors.add(kGetBackupStashError);
      throw Exception('lint_staged automatic backup is missing!');
    }

    /// https://github.com/okonet/lint_staged/issues/1121
    /// Detect MSYS in login shell mode and escape braces
    /// to prevent interpolation
    if (Platform.environment['MSYSTEM']?.isNotEmpty == true &&
        Platform.environment['LOGINSHELL']?.isNotEmpty == true) {
      return 'refs/stash@\\{$index\\}';
    }

    return 'refs/stash@{$index}';
  }

  ///
  /// Get a list of unstaged deleted files
  ///
  Future<List<String>> getDeletedFiles() async {
    logger.debug('Getting deleted files...');
    final lsFiles = await execGit(['ls-files', '--deleted'],
        workingDirectory: workingDirectory);
    final files =
        lsFiles.split('\n').where((line) => line.trim().isNotEmpty).toList();
    logger.debug('Found deleted files: $files');
    return files;
  }

  ///
  /// Save meta information about ongoing git merge
  ///
  Future<void> backupMergeStatus() async {
    logger.debug('Backing up merge state...');
    await Future.wait([
      readFile(mergeHeadFilename, workingDirectory: workingDirectory)
          .then((value) => mergeHeadContent = value),
      readFile(mergeModeFilename, workingDirectory: workingDirectory)
          .then((value) => mergeModeContent = value),
      readFile(mergeMsgFilename, workingDirectory: workingDirectory)
          .then((value) => mergeModeContent = value)
    ]);
    logger.debug('Done backing up merge state!');
  }

  ///
  /// Restore meta information about ongoing git merge
  ///
  Future<void> restoreMergeStatus(LintStagedContext ctx) async {
    logger.debug('Restoring merge state...');
    try {
      await Future.wait([
        if (mergeHeadContent != null)
          writeFile(mergeHeadFilename, mergeHeadContent!,
              workingDirectory: workingDirectory),
        if (mergeModeContent != null)
          writeFile(mergeModeFilename, mergeModeContent!,
              workingDirectory: workingDirectory),
        if (mergeMsgContent != null)
          writeFile(mergeMsgFilename, mergeMsgContent!,
              workingDirectory: workingDirectory),
      ]);
      logger.debug('Done restoring merge state!');
    } catch (e) {
      logger.debug('Failed restoring merge state with error:');
      logger.debug(e.toString());
      handleError(
          Exception('Merge state could not be restored due to an error!'),
          ctx,
          kRestoreMergeStatusError);
    }
  }

  ///
  /// Get a list of all files with both staged and unstaged modifications.
  /// Renames have special treatment, since the single status line includes
  /// both the "from" and "to" filenames, where "from" is no longer on disk.
  ///
  Future<List<String>> getPartiallyStagedFiles() async {
    final status =
        await execGit(['status', '-z'], workingDirectory: workingDirectory);
    if (status.isEmpty) {
      return [];
    }

    ///
    /// See https://git-scm.com/docs/git-status#_short_format
    /// Entries returned in machine format are separated by a NUL character.
    /// The first letter of each entry represents current index status,
    /// and second the working tree. Index and working tree status codes are
    /// separated from the file name by a space. If an entry includes a
    /// renamed file, the file names are separated by a NUL character
    /// (e.g. `to`\0`from`)
    ///
    return status
        .split(RegExp(r'\x00(?=[ AMDRCU?!]{2} |$)'))
        .where((line) {
          if (line.length > 2) {
            final index = line[0];
            final workingTree = line[1];
            return index != ' ' &&
                workingTree != ' ' &&
                index != '?' &&
                workingTree != '?';
          }
          return false;
        })
        .map((line) => line.substring(min(3, line.length)))

        /// Remove first three letters (index, workingTree, and a whitespace)
        .where((e) => e.isNotEmpty)

        /// Filter empty string
        .toList();
  }

  ///
  /// Create a diff of partially staged files and backup stash if enabled.
  ///
  Future<void> prepare(LintStagedContext ctx) async {
    try {
      logger.debug('Backing up original state...');
      partiallyStagedFiles = await getPartiallyStagedFiles();
      if (partiallyStagedFiles.isNotEmpty) {
        ctx.hasPartiallyStagedFiles = true;
        final unstagedPatch = getHiddenFilepath(kPatchUnstaged);
        final files = processRenames(partiallyStagedFiles);
        await execGit([
          'diff',
          ...kGitDiffArgs,
          '--output',
          unstagedPatch,
          '--',
          ...files
        ], workingDirectory: workingDirectory);
      } else {
        ctx.hasPartiallyStagedFiles = false;
      }

      ///  If backup stash should be skipped, no need to continue
      if (!ctx.shouldBackup) {
        return;
      }

      /// When backup is enabled, the revert will clear ongoing merge status.
      await backupMergeStatus();

      /// Get a list of unstaged deleted files, because certain bugs might cause them to reappear:
      /// - in git versions =< 2.13.0 the `git stash --keep-index` option resurrects deleted files
      /// - git stash can't infer RD or MD states correctly, and will lose the deletion
      deletedFiles = await getDeletedFiles();

      // Save stash of all staged files.
      // The `stash create` command creates a dangling commit without removing any files,
      // and `stash store` saves it as an actual stash.
      final hash = await execGit(['stash', 'create'],
          workingDirectory: workingDirectory);
      await execGit(['stash', 'store', '--quiet', '--message', kStash, hash],
          workingDirectory: workingDirectory);

      logger.debug('Done backing up original state!');
    } catch (e) {
      handleError(e, ctx);
    }
  }

  ///
  /// Remove unstaged changes to all partially staged files, to avoid tasks from seeing them
  ///
  Future<void> hideUnstagedChanges(LintStagedContext ctx) async {
    try {
      final files = processRenames(partiallyStagedFiles, false);
      await execGit(['checkout', '--force', '--', ...files],
          workingDirectory: workingDirectory);
    } catch (e) {
      ///
      ///`git checkout --force` doesn't throw errors, so it shouldn't be possible to get here.
      // If this does fail, the handleError method will set ctx.gitError and lint_staged will fail.
      ///
      handleError(e, ctx, kHideUnstagedChangesError);
    }
  }

  ///
  /// Applies back task modifications, and unstaged changes hidden in the stash.
  /// In case of a merge-conflict retry with 3-way merge.
  ///
  Future<void> applyModifications(LintStagedContext ctx) async {
    logger.debug('Adding task modifications to index...');

    /// `matchedFileChunks` includes staged files that lint_staged originally detected and matched against a task.
    /// Add only these files so any 3rd-party edits to other files won't be included in the commit.
    /// These additions per chunk are run "serially" to prevent race conditions.
    /// Git add creates a lockfile in the repo causing concurrent operations to fail.
    for (var files in matchedFileChunks) {
      await execGit(['add', '--', ...files],
          workingDirectory: workingDirectory);
    }
    logger.debug('Done adding task modifications to index!');

    final stagedFilesAfterAdd = await execGit(
        getDiffArgs(diff: diff, diffFilter: diffFilter),
        workingDirectory: workingDirectory);
    if (stagedFilesAfterAdd.isEmpty && !allowEmpty) {
      handleError(Exception('Prevented an empty git commit!'), ctx,
          kApplyEmptyCommitError);
    }
  }

  ///
  /// Restore unstaged changes to partially changed files. If it at first fails,
  /// this is probably because of conflicts between new task modifications.
  /// 3-way merge usually fixes this, and in case it doesn't we should just give up and throw.
  ///
  Future<void> resotreUnstagedChanges(LintStagedContext ctx) async {
    logger.debug('Restoring unstaged changes...');
    final unstagedPatch = getHiddenFilepath(kPatchUnstaged);
    try {
      await execGit(['apply', ...kGitApplyArgs, unstagedPatch],
          workingDirectory: workingDirectory);
    } catch (applyError) {
      logger.debug('Error while restoring changes:');
      logger.debug(applyError.toString());
      logger.debug('Retrying with 3-way merge');
      try {
        // Retry with a 3-way merge if normal apply fails
        await execGit(['apply', ...kGitApplyArgs, '--3way', unstagedPatch],
            workingDirectory: workingDirectory);
      } catch (threeWayApplyError) {
        logger
            .debug('Error while restoring unstaged changes using 3-way merge:');
        logger.debug(threeWayApplyError.toString());
        handleError(
            Exception(
                'Unstaged changes could not be restored due to a merge conflict!'),
            ctx,
            kRestoreUnstagedChangesError);
      }
    }
  }

  ///
  /// Restore original HEAD state in case of errors
  ///
  Future<void> restoreOriginState(LintStagedContext ctx) async {
    try {
      logger.debug('Restoring original state...');
      await execGit(['reset', '--hard', 'HEAD'],
          workingDirectory: workingDirectory);
      await execGit(
          ['stash', 'apply', '--quiet', '--index', await getBackupStash(ctx)],
          workingDirectory: workingDirectory);

      /// Restore meta information about ongoing git merge
      await restoreMergeStatus(ctx);

      /// If stashing resurrected deleted files, clean them out
      await Future.wait(deletedFiles
          .map((file) => removeFile(file, workingDirectory: workingDirectory)));

      // Clean out patch
      await removeFile(getHiddenFilepath(kPatchUnstaged),
          workingDirectory: workingDirectory);

      logger.debug('Done restoring original state!');
    } catch (error) {
      handleError(error, ctx, kRestoreOriginalStateError);
    }
  }

  ///
  /// Drop the created stashes after everything has run
  ///
  Future<void> cleanup(LintStagedContext ctx) async {
    try {
      logger.debug('Dropping backup stash...');
      await execGit(['stash', 'drop', '--quiet', await getBackupStash(ctx)],
          workingDirectory: workingDirectory);
      logger.debug('Done dropping backup stash!');
    } catch (error) {
      handleError(error, ctx);
    }
  }

  void handleError(e, LintStagedContext ctx, [Symbol? symbol]) {
    ctx.errors.add(kGitError);
    if (symbol != null) {
      ctx.errors.add(symbol);
    }
    // throw e;
  }
}
