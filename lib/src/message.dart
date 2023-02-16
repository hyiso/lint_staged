String skippingBackupMsg(bool hasInitialCommit, [List<String>? diff]) {
  final reason = diff == null
      ? '`--diff` was used'
      : hasInitialCommit
          ? '`--no-stash` was used'
          : 'there\'s no initial commit yet';
  return 'Skipping backup because $reason. \n';
}

const kNotGitRepoMsg = 'Current directory is not a git directory!';

const kGetStagedFilesErrorMsg = 'Failed to get staged files!';

const kNoStagedFilesMsg = 'No staged files';

const kGitErrorMsg = 'lint_staged failed due to a git error.';

const kNoConfigurationMsg = 'No valid configuration found.';

const kPreventedEmptyCommitMsg = '''lint_staged prevented an empty git commit.
  Use the --allow-empty option to continue, or check your task configuration''';

const kRestoreStashExampleMsg =
    '''  Any lost modifications can be restored from a git stash:
    > git stash list
    stash@{0}: automatic lint-staged backup
    > git stash apply --index stash@{0}
''';
