import 'package:test/test.dart';

import '__fixtures__/config.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('handles merge conflicts', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      final defaultBranch =
          await project.git.stdout(['rev-parse', '--abbrev-ref', 'HEAD']);

      final fileInBranchA = 'String foo = "foo";\n';
      final fileInBranchB = 'String foo="bar";\n';
      final fileInBranchBFixed = 'String foo = "bar";\n';

      // Create one branch
      await project.git.run(['checkout', '-b', 'branch-a']);
      await project.fs.append('lib/main.dart', fileInBranchA);
      await project.fs.append('pubspec.yaml', kConfigFormatFix);
      await project.git.run(['add', '.']);

      await project.gitCommit(gitCommitArgs: ['-m commit a']);

      expect(await project.fs.read('lib/main.dart'), equals(fileInBranchA));

      await project.git.run(['checkout', defaultBranch]);

      // Create another branch
      await project.git.run(['checkout', '-b', 'branch-b']);
      await project.fs.append('lib/main.dart', fileInBranchB);
      await project.fs.append('pubspec.yaml', kConfigFormatFix);
      await project.git.run(['add', '.']);
      await project.gitCommit(gitCommitArgs: ['-m commit b']);
      expect(
          await project.fs.read('lib/main.dart'), equals(fileInBranchBFixed));

      // Merge first branch
      await project.git.run(['checkout', defaultBranch]);
      await project.git.run(['merge', 'branch-a']);
      expect(await project.fs.read('lib/main.dart'), equals(fileInBranchA));
      expect(await project.git.stdout(['log', '-1', '--pretty=%B']),
          contains('commit a'));

      // Merge second branch, causing merge conflict
      final merge = project.git.run(['merge', 'branch-b']);
      await expectLater(merge, throwsException);

      expect(
          await project.fs.read('lib/main.dart'),
          contains('<<<<<<< HEAD\n'
              'String foo = "foo";\n'
              '=======\n'
              'String foo = "bar";\n'
              '>>>>>>> branch-b\n'
              ''));

      // Fix conflict and commit using lint_staged
      await project.fs.write('lib/main.dart', fileInBranchB);
      expect(await project.fs.read('lib/main.dart'), equals(fileInBranchB));
      await project.git.run(['add', '.']);

      await project.gitCommit(gitCommitArgs: ['--no-edit']);

      // Nothing is wrong, so a new commit is created and file is pretty
      expect(await project.git.stdout(['rev-list', '--count', 'HEAD']),
          equals('4'));
      final log = await project.git.stdout(['log', '-1', '--pretty=%B']);
      expect(log, contains('Merge branch \'branch-b\''));
      expect(log, contains('Conflicts:'));
      expect(log, contains('lib/main.dart'));
      expect(
          await project.fs.read('lib/main.dart'), equals(fileInBranchBFixed));
    });
    test('handles merge conflict when task errors', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      final defaultBranch =
          await project.git.stdout(['rev-parse', '--abbrev-ref', 'HEAD']);

      final fileInBranchA = 'String foo = "foo";\n';
      final fileInBranchB = 'String foo="bar";\n';
      final fileInBranchBFixed = 'String foo = "bar";\n';

      // Create one branch
      await project.git.run(['checkout', '-b', 'branch-a']);
      await project.fs.append('lib/main.dart', fileInBranchA);
      await project.fs.append('pubspec.yaml', kConfigFormatFix);
      await project.git.run(['add', '.']);

      await project.gitCommit(gitCommitArgs: ['-m commit a']);

      expect(await project.fs.read('lib/main.dart'), equals(fileInBranchA));

      await project.git.run(['checkout', defaultBranch]);

      // Create another branch
      await project.git.run(['checkout', '-b', 'branch-b']);
      await project.fs.append('lib/main.dart', fileInBranchB);
      await project.fs.append('pubspec.yaml', kConfigFormatFix);
      await project.git.run(['add', '.']);
      await project.gitCommit(gitCommitArgs: ['-m commit b']);
      expect(
          await project.fs.read('lib/main.dart'), equals(fileInBranchBFixed));

      // Merge first branch
      await project.git.run(['checkout', defaultBranch]);
      await project.git.run(['merge', 'branch-a']);
      expect(await project.fs.read('lib/main.dart'), equals(fileInBranchA));
      expect(await project.git.stdout(['log', '-1', '--pretty=%B']),
          contains('commit a'));

      // Merge second branch, causing merge conflict
      await expectLater(
          project.git.run(['merge', 'branch-b']), throwsException);

      expect(
          await project.fs.read('lib/main.dart'),
          contains('<<<<<<< HEAD\n'
              'String foo = "foo";\n'
              '=======\n'
              'String foo = "bar";\n'
              '>>>>>>> branch-b\n'
              ''));

      // Fix conflict and commit using lint_staged
      await project.fs.write('lib/main.dart', fileInBranchB);
      expect(await project.fs.read('lib/main.dart'), equals(fileInBranchB));
      await project.git.run(['add', '.']);

      await project.fs.write('pubspec.yaml', kConfigFormatExit);

      await expectLater(project.gitCommit(), throwsException);

      // Something went wrong, so lintStaged failed and merge is still going
      expect(await project.git.stdout(['rev-list', '--count', 'HEAD']),
          equals('2'));
      expect(await project.git.status(),
          contains('All conflicts fixed but you are still merging'));
      expect(await project.fs.read('lib/main.dart'), equals(fileInBranchB));
    });
  });
}
