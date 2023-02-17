import 'package:lint_staged/src/file.dart';
import 'package:lint_staged/src/git.dart';
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('commits entire staged file when no errors from linter', () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatExit, workingDirectory: dir);

      // Stage formatted file
      await writeFile('lib/main.dart', kFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);

      // Run lint_staged to automatically format the file and commit formatted file
      await gitCommit(workingDirectory: dir);

      // Nothing is wrong, so a new commit created
      expect(
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir),
          equals('2'));
      expect(await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir),
          contains('test'));
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kFormattedDart));
    });

    test('commits entire staged file when no errors and linter modifies file',
        () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatFix, workingDirectory: dir);

      // Stage multi unformatted files
      await writeFile('lib/main.dart', kUnFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);

      await writeFile('lib/foo.dart', kUnFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/foo.dart'], workingDirectory: dir);

      // Run lint_staged to automatically format the file and commit formatted files
      await gitCommit(workingDirectory: dir);

      // Nothing was wrong so the empty commit is created
      expect(
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir),
          equals('2'));
      expect(await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir),
          contains('test'));
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kFormattedDart));
      expect(await readFile('lib/foo.dart', workingDirectory: dir),
          equals(kFormattedDart));
    });

    test('fails to commit entire staged file when errors from linter',
        () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatExit, workingDirectory: dir);

      // Stage unformatted file
      await writeFile('lib/main.dart', kUnFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);
      final status = await execGit(['status'], workingDirectory: dir);

      // Run lint_staged to automatically format the file and commit formatted files
      await expectLater(gitCommit(workingDirectory: dir), throwsException);

      // Nothing was wrong so the empty commit is created
      expect(
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir),
          equals('1'));
      expect(await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir),
          contains('initial commit'));
      expect(await execGit(['status'], workingDirectory: dir), equals(status));
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kUnFormattedDart));
    });

    test(
        'fails to commit entire staged file when errors from linter and linter modifies files',
        () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatFix, workingDirectory: dir);

      // Stage invalid file
      await writeFile('lib/main.dart', kInvalidDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);
      final status = await execGit(['status'], workingDirectory: dir);

      // Run lint_staged to automatically format the file and commit formatted files
      await expectLater(gitCommit(workingDirectory: dir), throwsException);

      // Nothing was wrong so the empty commit is created
      expect(
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir),
          equals('1'));
      expect(await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir),
          contains('initial commit'));
      expect(await execGit(['status'], workingDirectory: dir), equals(status));
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kInvalidDart));
    });

    test('clears unstaged changes when linter applies same changes', () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await appendFile('pubspec.yaml', kConfigFormatFix, workingDirectory: dir);

      // Stage unformatted file
      await appendFile('lib/main.dart', kUnFormattedDart,
          workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);

      // Replace unformatted file with formatted but do not stage changes
      await removeFile('lib/main.dart', workingDirectory: dir);
      await appendFile('lib/main.dart', kFormattedDart, workingDirectory: dir);

      // Run lint_staged to automatically format the file and commit formatted files
      await gitCommit(workingDirectory: dir);

      // Nothing was wrong so the empty commit is created
      expect(
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir),
          equals('2'));
      expect(await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir),
          contains('test'));

      // Latest commit contains pretty file
      // `git show` strips empty line from here here
      expect(
          await execGit(['show', 'HEAD:lib/main.dart'], workingDirectory: dir),
          equals(kFormattedDart.trim()));

      // Nothing is staged
      expect(await execGit(['status'], workingDirectory: dir),
          contains('nothing added to commit'));

      // File is pretty, and has been edited
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kFormattedDart));
    });

    test('runs chunked tasks when necessary', () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatExit, workingDirectory: dir);

      // Stage two files
      await writeFile('lib/main.dart', kFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);
      await writeFile('lib/foo.dart', kFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/foo.dart'], workingDirectory: dir);

      // Run lint_staged to automatically format the file and commit formatted files
      // Set maxArgLength low enough so that chunking is used
      await gitCommit(maxArgLength: 10, workingDirectory: dir);

      // Nothing was wrong so the empty commit is created
      expect(
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir),
          equals('2'));
      expect(await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir),
          contains('test'));
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kFormattedDart));
      expect(await readFile('lib/foo.dart', workingDirectory: dir),
          equals(kFormattedDart));
    });

    test('fails when backup stash is missing', () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);
      final config = '''lint_staged:
  .dart: git stash drop
''';
      await writeFile('pubspec.yaml', config, workingDirectory: dir);

      // Stage two files
      await writeFile('lib/main.dart', kFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);

      // Run lint_staged to automatically format the file and commit formatted files
      // Set maxArgLength low enough so that chunking is used
      final commit = gitCommit(maxArgLength: 10, workingDirectory: dir);

      expect(commit, throwsException);
    });

    test('works when a branch named stash exists', () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);
      await writeFile('pubspec.yaml', kConfigFormatExit, workingDirectory: dir);

      // create a new branch called stash
      await execGit(['branch', 'stash'], workingDirectory: dir);

      // Stage two files
      await writeFile('lib/main.dart', kFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);

      // Run lint_staged to automatically format the file and commit formatted file
      await gitCommit(workingDirectory: dir);

      // Nothing is wrong, so a new commit is created and file is pretty
      expect(
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir),
          equals('2'));
      expect(await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir),
          contains('test'));
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kFormattedDart));
    });
  });
}
