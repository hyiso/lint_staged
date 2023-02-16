import 'package:lint_staged/src/context.dart';
import 'package:lint_staged/src/symbols.dart';
import 'package:test/test.dart';

void main() {
  group('LintState', () {
    group('applyModificationsSkipped', () {
      test('should return false when backup is disabled', () {
        final ctx = getInitialContext()..shouldBackup = false;
        expect(ctx.applyModifationsSkipped, false);
      });

      test('should return error message when there is an unkown git error', () {
        final ctx = getInitialContext()
          ..shouldBackup = true
          ..errors = {kGitError};
        expect(ctx.applyModifationsSkipped, true);
      });
    });

    group('restoreUnstagedChangesSkipped', () {
      test('should return error message when there is an unkown git error', () {
        final ctx = getInitialContext()..errors = {kGitError};
        expect(ctx.restoreUnstagedChangesSkipped, true);
      });
    });

    group('restoreOriginalStateSkipped', () {
      test('should return error message when there is an unkown git error', () {
        final ctx = getInitialContext()..errors = {kGitError};
        expect(ctx.restoreOriginalStateSkipped, true);
      });
    });

    group('shouldSkipCleanup', () {
      test('should return error message when reverting to original state fails',
          () {
        final ctx = getInitialContext()..errors = {kRestoreOriginalStateError};
        expect(ctx.cleanupSkipped, true);
      });
    });
  });
}
