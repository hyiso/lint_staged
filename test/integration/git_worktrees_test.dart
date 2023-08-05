import 'package:path/path.dart' show join;
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('handles git worktrees', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      // create a new branch and add it as worktree
      final worktreeProject =
          IntegrationProject(join(project.path, 'worktree'));
      await project.git.run(['branch', 'test']);
      await project.git.run(['worktree', 'add', worktreeProject.path, 'test']);

      // Stage pretty file
      await worktreeProject.fs.writeFile('pubspec.yaml', kConfigFormatExit);
      await worktreeProject.fs.appendFile('lib/main.dart', kFormattedDart);
      await worktreeProject.git.run(['add', 'lib/main.dart']);

      // Run lint_staged with `dart format --set-exit-if-changed` and commit formatted file
      await worktreeProject.gitCommit();

      // Nothing is wrong, so a new commit is created
      expect(await worktreeProject.git.stdout(['rev-list', '--count', 'HEAD']),
          equals('2'));
      expect(await worktreeProject.git.stdout(['log', '-1', '--pretty=%B']),
          contains('test'));
      expect(await worktreeProject.fs.readFile('lib/main.dart'),
          equals(kFormattedDart));
    });
  });
}
