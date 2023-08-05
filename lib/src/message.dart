const kNotGitRepoMsg = 'Current directory is not a git directory!';

const kGetStagedFilesErrorMsg = 'Failed to get staged files!';

const kNoStagedFilesMsg = 'No staged files';

const kNoStagedFilesMatchedMsg = 'No staged files matched';

const kGitErrorMsg = 'lint_staged failed due to a git error.';

const kNoConfigurationMsg =
    'No `lint_staged` configuration found in pubspec.yaml.';

const kPreventedEmptyCommitMsg = '''lint_staged prevented an empty git commit.
  Use the `--allow-empty` option to continue, or check your task configuration''';

const kRestoreStashExampleMsg =
    '''  Any lost modifications can be restored from a git stash:
    > git stash list
    stash@{0}: automatic lint_staged backup
    > git stash apply --index stash@{0}
''';
