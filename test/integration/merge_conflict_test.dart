import 'package:test/test.dart';

import '__fixtures__/config.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('handles merge conflicts', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      final fileInBranchA = 'String foo = "foo";\n';
      final fileInBranchB = 'String foo="bar";\n';
      final fileInBranchBFixed = 'String foo = "bar";\n';

      // Create one branch
      await project.execGit(['checkout', '-b', 'branch-a']);
      await project.appendFile('lib/main.dart', fileInBranchA);
      await project.appendFile('pubspec.yaml', kConfigFormatFix);
      await project.execGit(['add', '.']);

      await project.gitCommit(gitCommitArgs: ['-m commit a']);

      expect(await project.readFile('lib/main.dart'), equals(fileInBranchA));

      await project.execGit(['checkout', 'main']);

      // Create another branch
      await project.execGit(['checkout', '-b', 'branch-b']);
      await project.appendFile('lib/main.dart', fileInBranchB);
      await project.appendFile('pubspec.yaml', kConfigFormatFix);
      await project.execGit(['add', '.']);
      await project.gitCommit(gitCommitArgs: ['-m commit b']);
      expect(
          await project.readFile('lib/main.dart'), equals(fileInBranchBFixed));

      // Merge first branch
      await project.execGit(['checkout', 'main']);
      await project.execGit(['merge', 'branch-a']);
      expect(await project.readFile('lib/main.dart'), equals(fileInBranchA));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('commit a'));

      // Merge second branch, causing merge conflict
      final merge = project.execGit(['merge', 'branch-b']);
      await expectLater(merge, throwsException);

      expect(
          await project.readFile('lib/main.dart'),
          contains('<<<<<<< HEAD\n'
              'String foo = "foo";\n'
              '=======\n'
              'String foo = "bar";\n'
              '>>>>>>> branch-b\n'
              ''));

      // Fix conflict and commit using lint_staged
      await project.writeFile('lib/main.dart', fileInBranchB);
      expect(await project.readFile('lib/main.dart'), equals(fileInBranchB));
      await project.execGit(['add', '.']);

      await project.gitCommit(gitCommitArgs: ['--no-edit']);

      // Nothing is wrong, so a new commit is created and file is pretty
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('4'));
      final log = await project.execGit(['log', '-1', '--pretty=%B']);
      expect(log, contains('Merge branch \'branch-b\''));
      expect(log, contains('Conflicts:'));
      expect(log, contains('lib/main.dart'));
      expect(
          await project.readFile('lib/main.dart'), equals(fileInBranchBFixed));
    });
    test('handles merge conflict when task errors', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      final fileInBranchA = 'String foo = "foo";\n';
      final fileInBranchB = 'String foo="bar";\n';
      final fileInBranchBFixed = 'String foo = "bar";\n';

      // Create one branch
      await project.execGit(['checkout', '-b', 'branch-a']);
      await project.appendFile('lib/main.dart', fileInBranchA);
      await project.appendFile('pubspec.yaml', kConfigFormatFix);
      await project.execGit(['add', '.']);

      await project.gitCommit(gitCommitArgs: ['-m commit a']);

      expect(await project.readFile('lib/main.dart'), equals(fileInBranchA));

      await project.execGit(['checkout', 'main']);

      // Create another branch
      await project.execGit(['checkout', '-b', 'branch-b']);
      await project.appendFile('lib/main.dart', fileInBranchB);
      await project.appendFile('pubspec.yaml', kConfigFormatFix);
      await project.execGit(['add', '.']);
      await project.gitCommit(gitCommitArgs: ['-m commit b']);
      expect(
          await project.readFile('lib/main.dart'), equals(fileInBranchBFixed));

      // Merge first branch
      await project.execGit(['checkout', 'main']);
      await project.execGit(['merge', 'branch-a']);
      expect(await project.readFile('lib/main.dart'), equals(fileInBranchA));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('commit a'));

      // Merge second branch, causing merge conflict
      await expectLater(
          project.execGit(['merge', 'branch-b']), throwsException);

      expect(
          await project.readFile('lib/main.dart'),
          contains('<<<<<<< HEAD\n'
              'String foo = "foo";\n'
              '=======\n'
              'String foo = "bar";\n'
              '>>>>>>> branch-b\n'
              ''));

      // Fix conflict and commit using lint_staged
      await project.writeFile('lib/main.dart', fileInBranchB);
      expect(await project.readFile('lib/main.dart'), equals(fileInBranchB));
      await project.execGit(['add', '.']);

      await project.writeFile('pubspec.yaml', kConfigFormatExit);

      await expectLater(project.gitCommit(), throwsException);

      // Something went wrong, so lintStaged failed and merge is still going
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('2'));
      expect(await project.execGit(['status']),
          contains('All conflicts fixed but you are still merging'));
      expect(await project.readFile('lib/main.dart'), equals(fileInBranchB));
    });
  });
}
