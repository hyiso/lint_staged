import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('ignores untracked files', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.appendFile('pubspec.yaml', kConfigFormatExit);

      // Stage pretty file
      await project.appendFile('lib/main.dart', kFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);

      // Edit pretty file but do not stage changes
      final appended = '\nprint("test");\n';
      await project.appendFile('lib/main.dart', appended);

      await project.gitCommit();

      // Nothing is wrong, so a new commit is created and file is pretty
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('2'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('test'));

      // Latest commit contains pretty file
      // `git show` strips empty line from here here
      expect(await project.execGit(['show', 'HEAD:lib/main.dart']),
          equals(kFormattedDart.trim()));

      // Since edit was not staged, the file is still modified
      final status = await project.execGit(['status']);
      expect(status, contains('modified:   lib/main.dart'));
      expect(status, contains('no changes added to commit'));

      expect(await project.readFile('lib/main.dart'),
          equals(kFormattedDart + appended));
    });
    test(
        'commits partial change from partially staged file when no errors from linter and linter modifies file',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.appendFile('pubspec.yaml', kConfigFormatFix);

      // Stage ugly file
      await project.appendFile('lib/main.dart', kUnFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);

      // Edit ugly file but do not stage changes
      final appended = '\n\nprint("test");\n';
      await project.appendFile('lib/main.dart', appended);

      await project.gitCommit();

      // Nothing is wrong, so a new commit is created and file is pretty
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('2'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('test'));

      // Latest commit contains pretty file
      // `git show` strips empty line from here here
      expect(await project.execGit(['show', 'HEAD:lib/main.dart']),
          equals(kFormattedDart.trim()));

      // Nothing is staged
      final status = await project.execGit(['status']);
      expect(status, contains('modified:   lib/main.dart'));
      expect(status, contains('no changes added to commit'));

      // File is pretty, and has been edited
      expect(await project.readFile('lib/main.dart'),
          equals(kFormattedDart + appended));
    });
    test(
        'fails to commit partial change from partially staged file when errors from linter',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.appendFile('pubspec.yaml', kConfigFormatExit);

      // Stage ugly file
      await project.appendFile('lib/main.dart', kUnFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);

      // Edit ugly file but do not stage changes
      final appended = '\nprint("test");\n';
      await project.appendFile('lib/main.dart', appended);
      final status = await project.execGit(['status']);

      // Run lint_staged with `dart format --set-exit-if-changed` to break the linter
      await expectLater(project.gitCommit(), throwsException);

      // Something was wrong so the repo is returned to original state
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('1'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('initial commit'));
      expect(await project.execGit(['status']), equals(status));
      expect(await project.readFile('lib/main.dart'),
          equals(kUnFormattedDart + appended));
    });
    test(
        'fails to commit partial change from partially staged file when errors from linter and linter modifies files',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.appendFile('pubspec.yaml', kConfigFormatFix);

      // Add unfixable file to commit so `prettier --write` breaks
      await project.appendFile('lib/main.dart', kInvalidDart);
      await project.execGit(['add', 'lib/main.dart']);

      // Edit unfixable file but do not stage changes
      final appended = '\nprint("test");\n';
      await project.appendFile('lib/main.dart', appended);
      final status = await project.execGit(['status']);

      await expectLater(project.gitCommit(), throwsException);

      // Something was wrong so the repo is returned to original state
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('1'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('initial commit'));
      expect(await project.execGit(['status']), equals(status));
      expect(await project.readFile('lib/main.dart'),
          equals(kInvalidDart + appended));
    });
  });
}
