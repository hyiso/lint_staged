import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('works when amending previous commit with unstaged changes', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.write('pubspec.yaml', kConfigFormatExit);

      // Edit file from previous commit
      await project.fs.append('README.md', '\n## Amended\n');
      await project.git.run(['add', 'README.md']);

      // Edit again, but keep it unstaged
      await project.fs.append('README.md', '\n## Edited\n');
      await project.fs.append('lib/main.dart', kFormattedDart);

      // Run lint_staged with `dart format --set-exit-if-changed` and commit formatted file
      await project.gitCommit(gitCommitArgs: ['--amend', '--no-edit']);

      // Nothing is wrong, so the commit was amended
      expect(await project.git.stdout(['rev-list', '--count', 'HEAD']),
          equals('1'));
      expect(await project.git.stdout(['log', '-1', '--pretty=%B']),
          contains('initial commit'));
      expect(
          await project.fs.read('README.md'),
          contains('# Test\n'
              '\n## Amended\n'
              '\n## Edited\n'));
      expect(await project.fs.read('lib/main.dart'), equals(kFormattedDart));
      final status = await project.git.status();
      expect(status, contains('modified:   README.md'));
      expect(status, contains('lib/'));
      expect(status, contains('no changes added to commit'));
    });
  });
}
