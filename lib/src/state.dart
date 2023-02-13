import 'symbols.dart';

class LintState {
  bool hasPartiallyStagedFiles = false;
  bool shouldBackup = false;
  Set<Object> errors = {};
  List<String> output = [];

  bool get applyModifationsSkipped {
    /// Always apply back unstaged modifications when skipping backup
    if (!shouldBackup) return false;

    /// Should be skipped in case of git errors
    if (errors.contains(kGitError)) {
      return true;
    }

    /// Should be skipped when tasks fail
    if (errors.contains(kTaskError)) {
      return true;
    }
    return false;
  }

  bool get restoreUnstagedChangesSkipped {
    /// Should be skipped in case of git errors
    if (errors.contains(kGitError)) {
      return true;
    }

    /// Should be skipped when tasks fail
    if (errors.contains(kTaskError)) {
      return true;
    }
    return false;
  }

  bool get restoreOriginalStateEnabled =>
      shouldBackup &&
      (errors.contains(kTaskError) ||
          errors.contains(kApplyEmptyCommitError) ||
          errors.contains(kRestoreUnstagedChangesError));

  bool get restoreOriginalStateSkipped {
    // Should be skipped in case of unknown git errors
    if (errors.contains(kGitError) &&
        !errors.contains(kApplyEmptyCommitError) &&
        !errors.contains(kRestoreUnstagedChangesError)) {
      return true;
    }
    return false;
  }

  bool get cleanupEnabled => shouldBackup;

  bool get cleanupSkipped {
    // Should be skipped in case of unknown git errors
    if (errors.contains(kGitError) &&
        !errors.contains(kApplyEmptyCommitError) &&
        !errors.contains(kRestoreUnstagedChangesError)) {
      return true;
    }
    // Should be skipped when reverting to original state fails
    if (errors.contains(kRestoreOriginalStateError)) {
      return true;
    }
    return false;
  }
}

LintState getInitialState() => LintState();
