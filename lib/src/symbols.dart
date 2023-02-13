const kApplyEmptyCommitError = Symbol('ApplyEmptyCommitError');

const kConfigNotFoundError = Symbol('Configuration could not be found');

const kConfigFormatError =
    Symbol('Configuration should be an object or a function');

const kConfigEmptyError = Symbol('Configuration should not be empty');

const kGetBackupStashError = Symbol('GetBackupStashError');

const kGetStagedFilesError = Symbol('GetStagedFilesError');

const kGitError = Symbol('GitError');

const kGitRepoError = Symbol('GitRepoError');

const kHideUnstagedChangesError = Symbol('HideUnstagedChangesError');

const kInvalidOptionsError = Symbol('Invalid Options');

const kRestoreMergeStatusError = Symbol('RestoreMergeStatusError');

const kRestoreOriginalStateError = Symbol('RestoreOriginalStateError');

const kRestoreUnstagedChangesError = Symbol('RestoreUnstagedChangesError');

const kTaskError = Symbol('TaskError');
