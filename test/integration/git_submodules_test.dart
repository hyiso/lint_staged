import 'package:lint_staged/src/file.dart';
import 'package:lint_staged/src/git.dart';
import 'package:path/path.dart' show join;
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('handles git submodules', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.writeFile('pubspec.yaml', kConfigFormatFix);
      await project.writeFile('lib/main.dart', kFormattedDart);
      await project.execGit(['add', '.']);
      await expectLater(
          project.gitCommit(gitCommitArgs: ['-m', 'committed pretty file']),
          completes);

      // create a new repo for the git submodule to a temp path
      final submoduleProject = IntegrationProject();
      await submoduleProject.setup();

      /// Add the newly-created repo as a submodule in a new path.
      /// This simulates adding it from a remote. By default file protocol is not allowed,
      /// see https://git-scm.com/docs/git-config#Documentation/git-config.txt-protocolallow
      await project.execGit([
        '-c',
        'protocol.file.allow=always',
        'submodule',
        'add',
        '--force',
        submoduleProject.dir,
        './submodule',
      ]);

      /// Commit this submodule
      await project.execGit(['add', '.']);
      await expectLater(
          project.gitCommit(
              allowEmpty: true, gitCommitArgs: ['-m', 'Add submodule']),
          completes);

      final submodulePath = join(project.dir, 'submodule');
      await writeFile('pubspec.yaml', kConfigFormatExit,
          workingDirectory: submodulePath);

      /// Stage pretty file
      await appendFile('lib/main.dart', kFormattedDart,
          workingDirectory: submodulePath);
      await execGit(['add', '.'], workingDirectory: submodulePath);

      /// Run lint_staged with `dart format --set-exit-if-changed` and commit formatted file
      await project.config(submodulePath);
      await expectLater(
          project.gitCommit(workingDirectory: submodulePath), completes);

      /// Nothing is wrong, so a new commit is created
      expect(
          await execGit(['rev-list', '--count', 'HEAD'],
              workingDirectory: submodulePath),
          equals('2'));
      expect(
          await execGit(['log', '-1', '--pretty=%B'],
              workingDirectory: submodulePath),
          contains('test'));
      expect(await readFile('lib/main.dart', workingDirectory: submodulePath),
          equals(kFormattedDart));

      /// Commit this submodule
      await project.execGit(['add', '.']);
      await expectLater(
          project.gitCommit(
              allowEmpty: true, gitCommitArgs: ['-m', 'Update submodule']),
          completes);
    });
  });
}
