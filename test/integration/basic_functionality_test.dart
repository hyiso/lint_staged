import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('commits entire staged file when no errors from linter', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.writeFile('pubspec.yaml', kConfigFormatExit);

      // Stage formatted file
      await project.writeFile('lib/main.dart', kFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);

      // Run lint_staged to automatically format the file and commit formatted file
      await project.gitCommit();

      // Nothing is wrong, so a new commit created
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('2'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('test'));
      expect(await project.readFile('lib/main.dart'), equals(kFormattedDart));
    });

    test('commits entire staged file when no errors and linter modifies file',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.writeFile('pubspec.yaml', kConfigFormatFix);

      // Stage multi unformatted files
      await project.writeFile('lib/main.dart', kUnFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);

      await project.writeFile('lib/foo.dart', kUnFormattedDart);
      await project.execGit(['add', 'lib/foo.dart']);

      // Run lint_staged to automatically format the file and commit formatted files
      await project.gitCommit();

      // Nothing was wrong so the empty commit is created
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('2'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('test'));
      expect(await project.readFile('lib/main.dart'), equals(kFormattedDart));
      expect(await project.readFile('lib/foo.dart'), equals(kFormattedDart));
    });

    test('fails to commit entire staged file when errors from linter',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.writeFile('pubspec.yaml', kConfigFormatExit);

      // Stage unformatted file
      await project.writeFile('lib/main.dart', kUnFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);
      final status = await project.execGit(['status']);

      // Run lint_staged to automatically format the file and commit formatted files
      await expectLater(project.gitCommit(), throwsException);

      // Nothing was wrong so the empty commit is created
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('1'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('initial commit'));
      expect(await project.execGit(['status']), equals(status));
      expect(await project.readFile('lib/main.dart'), equals(kUnFormattedDart));
    });

    test(
        'fails to commit entire staged file when errors from linter and linter modifies files',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.writeFile('pubspec.yaml', kConfigFormatFix);

      // Stage invalid file
      await project.writeFile('lib/main.dart', kInvalidDart);
      await project.execGit(['add', 'lib/main.dart']);
      final status = await project.execGit(['status']);

      // Run lint_staged to automatically format the file and commit formatted files
      await expectLater(project.gitCommit(), throwsException);

      // Nothing was wrong so the empty commit is created
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('1'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('initial commit'));
      expect(await project.execGit(['status']), equals(status));
      expect(await project.readFile('lib/main.dart'), equals(kInvalidDart));
    });

    test('clears unstaged changes when linter applies same changes', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.appendFile('pubspec.yaml', kConfigFormatFix);

      // Stage unformatted file
      await project.appendFile(
        'lib/main.dart',
        kUnFormattedDart,
      );
      await project.execGit(['add', 'lib/main.dart']);

      // Replace unformatted file with formatted but do not stage changes
      await project.removeFile('lib/main.dart');
      await project.appendFile('lib/main.dart', kFormattedDart);

      // Run lint_staged to automatically format the file and commit formatted files
      await project.gitCommit();

      // Nothing was wrong so the empty commit is created
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('2'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('test'));

      // Latest commit contains pretty file
      // `git show` strips empty line from here here
      expect(await project.execGit(['show', 'HEAD:lib/main.dart']),
          equals(kFormattedDart.trim()));

      // Nothing is staged
      expect(await project.execGit(['status']),
          contains('nothing added to commit'));

      // File is pretty, and has been edited
      expect(await project.readFile('lib/main.dart'), equals(kFormattedDart));
    });

    test('runs chunked tasks when necessary', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.writeFile('pubspec.yaml', kConfigFormatExit);

      // Stage two files
      await project.writeFile('lib/main.dart', kFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);
      await project.writeFile('lib/foo.dart', kFormattedDart);
      await project.execGit(['add', 'lib/foo.dart']);

      // Run lint_staged to automatically format the file and commit formatted files
      // Set maxArgLength low enough so that chunking is used
      await project.gitCommit(maxArgLength: 10);

      // Nothing was wrong so the empty commit is created
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('2'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('test'));
      expect(await project.readFile('lib/main.dart'), equals(kFormattedDart));
      expect(await project.readFile('lib/foo.dart'), equals(kFormattedDart));
    });

    test('fails when backup stash is missing', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();
      final config = '''lint_staged:
  .dart: git stash drop
''';
      await project.writeFile('pubspec.yaml', config);

      // Stage two files
      await project.writeFile('lib/main.dart', kFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);

      // Run lint_staged to automatically format the file and commit formatted files
      // Set maxArgLength low enough so that chunking is used
      expect(project.gitCommit(maxArgLength: 10), throwsException);
    });

    test('works when a branch named stash exists', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();
      await project.writeFile('pubspec.yaml', kConfigFormatExit);

      // create a new branch called stash
      await project.execGit(['branch', 'stash']);

      // Stage two files
      await project.writeFile('lib/main.dart', kFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);

      // Run lint_staged to automatically format the file and commit formatted file
      await project.gitCommit();

      // Nothing is wrong, so a new commit is created and file is pretty
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('2'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('test'));
      expect(await project.readFile('lib/main.dart'), equals(kFormattedDart));
    });
  });
}
