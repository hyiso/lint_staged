import 'symbols.dart';

class Context {
  bool hasPartiallyStagedFiles = false;
  bool shouldBackup = false;
  Set<Object> errors = {};
  List<String> output = [];
}

Context getInitialContext() => Context();

bool applyModifationsSkipped(Context ctx) {
  /// Always apply back unstaged modifications when skipping backup
  if (!ctx.shouldBackup) return false;

  /// Should be skipped in case of git errors
  if (ctx.errors.contains(kGitError)) {
    return true;
  }

  /// Should be skipped when tasks fail
  if (ctx.errors.contains(kTaskError)) {
    return true;
  }
  return false;
}

bool restoreUnstagedChangesSkipped(Context ctx) {
  /// Should be skipped in case of git errors
  if (ctx.errors.contains(kGitError)) {
    return true;
  }

  /// Should be skipped when tasks fail
  if (ctx.errors.contains(kTaskError)) {
    return true;
  }
  return false;
}

bool restoreOriginalStateEnabled(Context ctx) =>
    ctx.shouldBackup &&
    (ctx.errors.contains(kTaskError) ||
        ctx.errors.contains(kApplyEmptyCommitError) ||
        ctx.errors.contains(kRestoreUnstagedChangesError));

bool restoreOriginalStateSkipped(Context ctx) {
  // Should be skipped in case of unknown git errors
  if (ctx.errors.contains(kGitError) &&
      !ctx.errors.contains(kApplyEmptyCommitError) &&
      !ctx.errors.contains(kRestoreUnstagedChangesError)) {
    return true;
  }
  return false;
}

bool cleanupEnabled(Context ctx) => ctx.shouldBackup;

bool cleanupSkipped(Context ctx) {
  // Should be skipped in case of unknown git errors
  if (ctx.errors.contains(kGitError) &&
      !ctx.errors.contains(kApplyEmptyCommitError) &&
      !ctx.errors.contains(kRestoreUnstagedChangesError)) {
    return true;
  }
  // Should be skipped when reverting to original state fails
  if (ctx.errors.contains(kRestoreOriginalStateError)) {
    return true;
  }
  return false;
}
