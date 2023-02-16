import 'context.dart';

class LintStagedEeception implements Exception {
  /// Message describing the assertion error.
  final Object? message;

  /// LintStagedContext
  final LintStagedContext ctx;

  /// Creates an assertion error with the provided [message].
  LintStagedEeception(this.ctx, [this.message]);

  @override
  String toString() {
    if (message != null) {
      return "Assertion failed: ${Error.safeToString(message)}";
    }
    return "Assertion failed";
  }
}

LintStagedEeception createError(LintStagedContext ctx,
        [String message = 'lint_staged failed']) =>
    LintStagedEeception(ctx, message);
