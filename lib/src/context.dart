import 'symbols.dart';

class LintStagedContext {
  bool hasPartiallyStagedFiles = false;
  bool shouldBackup = false;
  Set<Object> errors = {};
  List<String> output = [];
}

LintStagedContext getInitialContext() => LintStagedContext();

bool applyModifationsSkipped(LintStagedContext ctx) {
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

bool restoreUnstagedChangesSkipped(LintStagedContext ctx) {
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

bool restoreOriginalStateEnabled(LintStagedContext ctx) =>
    ctx.shouldBackup &&
    (ctx.errors.contains(kTaskError) ||
        ctx.errors.contains(kApplyEmptyCommitError) ||
        ctx.errors.contains(kRestoreUnstagedChangesError));

bool restoreOriginalStateSkipped(LintStagedContext ctx) {
  // Should be skipped in case of unknown git errors
  if (ctx.errors.contains(kGitError) &&
      !ctx.errors.contains(kApplyEmptyCommitError) &&
      !ctx.errors.contains(kRestoreUnstagedChangesError)) {
    return true;
  }
  return false;
}

bool cleanupEnabled(LintStagedContext ctx) => ctx.shouldBackup;

bool cleanupSkipped(LintStagedContext ctx) {
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
