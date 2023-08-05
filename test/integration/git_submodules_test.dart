import 'package:path/path.dart' show join;
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('handles git submodules', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.writeFile('pubspec.yaml', kConfigFormatFix);
      await project.fs.writeFile('lib/main.dart', kFormattedDart);
      await project.git.run(['add', '.']);
      await expectLater(
          project.gitCommit(gitCommitArgs: ['-m', 'committed pretty file']),
          completes);

      // create a new repo for the git submodule to a temp path
      final anotherProject = IntegrationProject();
      await anotherProject.setup();

      /// Add the newly-created repo as a submodule in a new path.
      /// This simulates adding it from a remote. By default file protocol is not allowed,
      /// see https://git-scm.com/docs/git-config#Documentation/git-config.txt-protocolallow
      await project.git.run([
        '-c',
        'protocol.file.allow=always',
        'submodule',
        'add',
        '--force',
        anotherProject.path,
        './submodule',
      ]);

      /// Commit this submodule
      await project.git.run(['add', '.']);
      await expectLater(
          project.gitCommit(
              allowEmpty: true, gitCommitArgs: ['-m', 'Add submodule']),
          completes);

      final submoduleProject =
          IntegrationProject(join(project.path, 'submodule'));
      await submoduleProject.fs.writeFile('pubspec.yaml', kConfigFormatExit);

      /// Stage pretty file
      await submoduleProject.fs.appendFile('lib/main.dart', kFormattedDart);
      await submoduleProject.git.run(['add', '.']);

      /// Run lint_staged with `dart format --set-exit-if-changed` and commit formatted file
      await submoduleProject.config();
      await expectLater(submoduleProject.gitCommit(), completes);

      /// Nothing is wrong, so a new commit is created
      expect(await submoduleProject.git.stdout(['rev-list', '--count', 'HEAD']),
          equals('2'));
      expect(await submoduleProject.git.stdout(['log', '-1', '--pretty=%B']),
          contains('test'));
      expect(await submoduleProject.fs.readFile('lib/main.dart'),
          equals(kFormattedDart));

      /// Commit this submodule
      await project.git.run(['add', '.']);
      await expectLater(
          project.gitCommit(
              allowEmpty: true, gitCommitArgs: ['-m', 'Update submodule']),
          completes);
    });
  });
}
