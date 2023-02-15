import 'package:lint_staged/src/git_workflow.dart';
import 'package:lint_staged/src/state.dart';
import 'package:lint_staged/src/symbols.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('GitWorkflow', () {
    test('getBackupStash should throw when stash not found', () async {
      final gitWorkflow = GitWorkflow(gitConfigDir: '.');
      final ctx = getInitialState();
      await expectLater(() async {
        await gitWorkflow.getBackupStash(ctx);
      }, throwsException);
      expect(ctx.errors.contains(kGetBackupStashError), true);
    });
  });
}
