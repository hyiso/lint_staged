import 'package:lint_staged/src/file.dart';
import 'package:lint_staged/src/git.dart';
import 'package:path/path.dart' show join;
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('handles git worktrees', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      // create a new branch and add it as worktree
      final workTreeDir = join(project.dir, 'worktree');
      await project.execGit(['branch', 'test']);
      await project.execGit(['worktree', 'add', workTreeDir, 'test']);

      // Stage pretty file
      await writeFile('pubspec.yaml', kConfigFormatExit,
          workingDirectory: workTreeDir);
      await appendFile('lib/main.dart', kFormattedDart,
          workingDirectory: workTreeDir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: workTreeDir);

      // Run lint_staged with `dart format --set-exit-if-changed` and commit formatted file
      await project.gitCommit(workingDirectory: workTreeDir);

      // Nothing is wrong, so a new commit is created
      expect(
          await execGit(['rev-list', '--count', 'HEAD'],
              workingDirectory: workTreeDir),
          equals('2'));
      expect(
          await execGit(['log', '-1', '--pretty=%B'],
              workingDirectory: workTreeDir),
          contains('test'));
      expect(await readFile('lib/main.dart', workingDirectory: workTreeDir),
          equals(kFormattedDart));
    });
  });
}
