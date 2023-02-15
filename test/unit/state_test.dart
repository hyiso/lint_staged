import 'package:lint_staged/src/state.dart';
import 'package:lint_staged/src/symbols.dart';
import 'package:test/test.dart';

void main() {
  group('LintState', () {
    group('applyModificationsSkipped', () {
      test('should return false when backup is disabled', () {
        final ctx = getInitialState()..shouldBackup = false;
        expect(ctx.applyModifationsSkipped, false);
      });

      test('should return error message when there is an unkown git error', () {
        final ctx = getInitialState()
          ..shouldBackup = true
          ..errors = {kGitError};
        expect(ctx.applyModifationsSkipped, true);
      });
    });

    group('restoreUnstagedChangesSkipped', () {
      test('should return error message when there is an unkown git error', () {
        final ctx = getInitialState()..errors = {kGitError};
        expect(ctx.restoreUnstagedChangesSkipped, true);
      });
    });

    group('restoreOriginalStateSkipped', () {
      test('should return error message when there is an unkown git error', () {
        final ctx = getInitialState()..errors = {kGitError};
        expect(ctx.restoreOriginalStateSkipped, true);
      });
    });

    group('shouldSkipCleanup', () {
      test('should return error message when reverting to original state fails',
          () {
        final ctx = getInitialState()..errors = {kRestoreOriginalStateError};
        expect(ctx.cleanupSkipped, true);
      });
    });
  });
}
