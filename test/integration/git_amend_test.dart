import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('works when amending previous commit with unstaged changes', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.writeFile('pubspec.yaml', kConfigFormatExit);

      // Edit file from previous commit
      await project.appendFile('README.md', '\n## Amended\n');
      await project.execGit(['add', 'README.md']);

      // Edit again, but keep it unstaged
      await project.appendFile('README.md', '\n## Edited\n');
      await project.appendFile('lib/main.dart', kFormattedDart);

      // Run lint-staged with `prettier --list-different` and commit pretty file
      await project.gitCommit(gitCommitArgs: ['--amend', '--no-edit']);

      // Nothing is wrong, so the commit was amended
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('1'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('initial commit'));
      expect(
          await project.readFile('README.md'),
          contains('# Test\n'
              '\n## Amended\n'
              '\n## Edited\n'));
      expect(await project.readFile('lib/main.dart'), equals(kFormattedDart));
      final status = await project.execGit(['status']);
      expect(status, contains('modified:   README.md'));
      expect(status, contains('lib/'));
      expect(status, contains('no changes added to commit'));
    });
  });
}
