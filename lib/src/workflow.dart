import 'package:path/path.dart' show join;
import 'package:verbose/verbose.dart';

import 'context.dart';
import 'fs.dart';
import 'git.dart';
import 'symbols.dart';

/// In git status machine output, renames are presented as `to`NUL`from`
/// When diffing, both need to be taken into account, but in some cases on the `to`.
final _renameRegex = RegExp(r'\x00');

final _verbose = Verbose('lint_staged:workflow');

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

const _kStashMessage = 'lint_staged automatic backup';

const _kGitDiffArgs = [
  '--binary', // support binary files
  '--unified=0', // do not add lines around diff for consistent behaviour
  '--no-color', // disable colors for consistent behaviour
  '--no-ext-diff', // disable external diff tools for consistent behaviour
  '--src-prefix=a/', // force prefix for consistent behaviour
  '--dst-prefix=b/', // force prefix for consistent behaviour
  '--patch', // output a patch that can be applied
  '--submodule=short', // always use the default short format for submodules
];
const _kGitApplyArgs = [
  '-v',
  '--whitespace=nowarn',
  '--recount',
  '--unidiff-zero'
];

class Workflow {
  final Git git;
  final FileSystem fs;
  final Context ctx;
  final bool allowEmpty;
  final List<List<String>> matchedFileChunks;

  late List<String> _partiallyStagedFiles;
  late List<String> _deletedFiles;

  ///
  /// These three files hold state about an ongoing git merge
  /// Resolve paths during constructor
  ///
  late final String _mergeHeadFilename = join(git.gitdir, 'MERGE_HEAD');
  late final String _mergeModeFilename = join(git.gitdir, 'MERGE_MODE');
  late final String _mergeMsgFilename = join(git.gitdir, 'MERGE_MSG');
  late final String _unstagedFilename =
      join(git.gitdir, 'lint_staged_unstaged.patch');

  String? mergeHeadContent;
  String? mergeModeContent;
  String? mergeMsgContent;

  Workflow({
    required this.fs,
    required this.git,
    required this.ctx,
    this.allowEmpty = false,
    this.matchedFileChunks = const [],
  });

  ///
  /// Get name of backup stash
  ///
  Future<String> getBackupStash() async {
    final index = await git.getStashMessageIndex(_kStashMessage);
    if (index == -1) {
      ctx.errors.add(kGetBackupStashError);
      throw Exception('lint_staged automatic backup is missing!');
    }
    return index.toString();
  }

  ///
  /// Save meta information about ongoing git merge
  ///
  Future<void> backupMergeStatus() async {
    await Future.wait([
      fs.read(_mergeHeadFilename).then((value) => mergeHeadContent = value),
      fs.read(_mergeModeFilename).then((value) => mergeModeContent = value),
      fs.read(_mergeMsgFilename).then((value) => mergeModeContent = value)
    ]);
  }

  ///
  /// Restore meta information about ongoing git merge
  ///
  Future<void> restoreMergeStatus() async {
    try {
      await Future.wait([
        if (mergeHeadContent != null)
          fs.write(_mergeHeadFilename, mergeHeadContent!),
        if (mergeModeContent != null)
          fs.write(_mergeModeFilename, mergeModeContent!),
        if (mergeMsgContent != null)
          fs.write(_mergeMsgFilename, mergeMsgContent!),
      ]);
    } catch (error, stack) {
      _verbose(error.toString());
      _verbose(stack.toString());
      handleError(
          Exception('Merge state could not be restored due to an error!'),
          kRestoreMergeStatusError);
    }
  }

  ///
  /// Create a diff of partially staged files and backup stash if enabled.
  ///
  Future<void> prepare() async {
    try {
      _partiallyStagedFiles = await git.partiallyStagedFiles;
      if (_partiallyStagedFiles.isNotEmpty) {
        ctx.hasPartiallyStagedFiles = true;
        final files = processRenames(_partiallyStagedFiles);
        await git.run([
          'diff',
          ..._kGitDiffArgs,
          '--output',
          _unstagedFilename,
          '--',
          ...files
        ]);
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
      _deletedFiles = await git.deletedFiles;

      /// Save stash of all staged files.
      /// and `stash store` saves it as an actual stash.
      final stash = await git.createStash();

      /// Whether there's nothing to stash.
      if (stash.isNotEmpty) {
        await git.storeStash(stash, message: _kStashMessage);
      }
    } catch (error, stack) {
      _verbose(error.toString());
      _verbose(stack.toString());
      handleError(error);
    }
  }

  ///
  /// Remove unstaged changes to all partially staged files, to avoid tasks from seeing them
  ///
  Future<void> hideUnstagedChanges() async {
    try {
      final files = processRenames(_partiallyStagedFiles, false);
      await git.run(['checkout', '--force', '--', ...files]);
    } catch (error, stack) {
      _verbose(error.toString());
      _verbose(stack.toString());

      ///
      ///`git checkout --force` doesn't throw errors, so it shouldn't be possible to get here.
      // If this does fail, the handleError method will set ctx.gitError and lint_staged will fail.
      ///
      handleError(error, kHideUnstagedChangesError);
    }
  }

  ///
  /// Applies back task modifications, and unstaged changes hidden in the stash.
  /// In case of a merge-conflict retry with 3-way merge.
  ///
  Future<void> applyModifications() async {
    /// `matchedFileChunks` includes staged files that lint_staged originally detected and matched against a task.
    /// Add only these files so any 3rd-party edits to other files won't be included in the commit.
    /// These additions per chunk are run "serially" to prevent race conditions.
    /// Git add creates a lockfile in the repo causing concurrent operations to fail.
    for (var files in matchedFileChunks) {
      await git.run(['add', '--', ...files]);
    }
    final stagedFilesAfterAdd = await git.stagedFiles;
    if (stagedFilesAfterAdd.isEmpty && !allowEmpty) {
      handleError(
          Exception('Prevented an empty git commit!'), kApplyEmptyCommitError);
    }
  }

  ///
  /// Restore unstaged changes to partially changed files. If it at first fails,
  /// this is probably because of conflicts between new task modifications.
  /// 3-way merge usually fixes this, and in case it doesn't we should just give up and throw.
  ///
  Future<void> resotreUnstagedChanges() async {
    try {
      await git.run(['apply', ..._kGitApplyArgs, _unstagedFilename]);
    } catch (_) {
      _verbose('Error while restoring changes:');
      _verbose('Retrying with 3-way merge');
      try {
        // Retry with a 3-way merge if normal apply fails
        await git
            .run(['apply', ..._kGitApplyArgs, '--3way', _unstagedFilename]);
      } catch (error, stack) {
        _verbose('Error while restoring unstaged changes using 3-way merge:');
        _verbose(error.toString());
        _verbose(stack.toString());
        handleError(error, kRestoreUnstagedChangesError);
      }
    }
  }

  ///
  /// Restore original HEAD state in case of errors
  ///
  Future<void> restoreOriginState() async {
    try {
      await git.run(['reset', '--hard', 'HEAD']);
      final backupStash = await getBackupStash();
      await git.run(['stash', 'apply', '--quiet', '--index', backupStash]);

      /// Restore meta information about ongoing git merge
      await restoreMergeStatus();

      /// If stashing resurrected deleted files, clean them out
      await Future.wait(_deletedFiles.map((file) => fs.remove(file)));

      // Clean out patch
      await fs.remove(_unstagedFilename);
    } catch (error, stack) {
      _verbose(error.toString());
      _verbose(stack.toString());
      handleError(error, kRestoreOriginalStateError);
    }
  }

  ///
  /// Drop the created stashes after everything has run
  ///
  Future<void> cleanup() async {
    try {
      await git.run(['stash', 'drop', '--quiet', await getBackupStash()]);
    } catch (error, stack) {
      _verbose(error.toString());
      _verbose(stack.toString());
      handleError(error);
    }
  }

  void handleError(dynamic error, [Symbol? symbol]) {
    ctx.errors.add(kGitError);
    if (symbol != null) {
      ctx.errors.add(symbol);
    }
    // throw error;
  }
}
