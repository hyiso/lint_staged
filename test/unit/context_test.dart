import 'package:lint_staged/src/context.dart';
import 'package:lint_staged/src/symbols.dart';
import 'package:test/test.dart';

void main() {
  group('LintStagedContext', () {
    group('applyModificationsSkipped', () {
      test('should return false when backup is disabled', () {
        final ctx = getInitialContext()..shouldBackup = false;
        expect(applyModifationsSkipped(ctx), false);
      });

      test('should return error message when there is an unkown git error', () {
        final ctx = getInitialContext()
          ..shouldBackup = true
          ..errors = {kGitError};
        expect(applyModifationsSkipped(ctx), true);
      });
    });

    group('restoreUnstagedChangesSkipped', () {
      test('should return error message when there is an unkown git error', () {
        final ctx = getInitialContext()..errors = {kGitError};
        expect(restoreUnstagedChangesSkipped(ctx), true);
      });
    });

    group('restoreOriginalStateSkipped', () {
      test('should return error message when there is an unkown git error', () {
        final ctx = getInitialContext()..errors = {kGitError};
        expect(restoreOriginalStateSkipped(ctx), true);
      });
    });

    group('shouldSkipCleanup', () {
      test('should return error message when reverting to original state fails',
          () {
        final ctx = getInitialContext()..errors = {kRestoreOriginalStateError};
        expect(cleanupSkipped(ctx), true);
      });
    });
  });
}
