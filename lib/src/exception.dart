import 'context.dart';

class LintStagedException implements Exception {
  /// Message describing the assertion error.
  final Object? message;

  /// LintStagedContext
  final LintStagedContext ctx;

  /// Creates an assertion error with the provided [message].
  LintStagedException(this.ctx, [this.message]);

  @override
  String toString() {
    if (message != null) {
      return "lint_staged failed: ${Error.safeToString(message)}";
    }
    return "lint_staged failed";
  }
}

LintStagedException createError(LintStagedContext ctx, [String? message]) =>
    LintStagedException(ctx, message);
