import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('commits entire staged file when no errors from linter', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.write('pubspec.yaml', kConfigFormatExit);

      // Stage formatted file
      await project.fs.write('lib/main.dart', kFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);

      // Run lint_staged to automatically format the file and commit formatted file
      await project.gitCommit();

      // Nothing is wrong, so a new commit created
      expect(await project.git.commitCount, equals(2));
      expect(await project.git.lastCommit, contains('test'));
      expect(await project.fs.read('lib/main.dart'), equals(kFormattedDart));
    });

    test('commits entire staged file when no errors and linter modifies file',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.write('pubspec.yaml', kConfigFormatFix);

      // Stage multi unformatted files
      await project.fs.write('lib/main.dart', kUnFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);

      await project.fs.write('lib/foo.dart', kUnFormattedDart);
      await project.git.run(['add', 'lib/foo.dart']);

      // Run lint_staged to automatically format the file and commit formatted files
      await project.gitCommit();

      // Nothing was wrong so the empty commit is created
      expect(await project.git.commitCount, equals(2));
      expect(await project.git.lastCommit, contains('test'));
      expect(await project.fs.read('lib/main.dart'), equals(kFormattedDart));
      expect(await project.fs.read('lib/foo.dart'), equals(kFormattedDart));
    });

    test('fails to commit entire staged file when errors from linter',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.write('pubspec.yaml', kConfigFormatExit);

      // Stage unformatted file
      await project.fs.write('lib/main.dart', kUnFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);
      final status = await project.git.status();

      // Run lint_staged to automatically format the file and commit formatted files
      await expectLater(project.gitCommit(), throwsIntegrationTestError);

      // Nothing was wrong so the empty commit is created
      expect(await project.git.commitCount, equals(1));
      expect(await project.git.lastCommit, contains('initial commit'));
      expect(await project.git.status(), equals(status));
      expect(await project.fs.read('lib/main.dart'), equals(kUnFormattedDart));
    });

    test(
        'fails to commit entire staged file when errors from linter and linter modifies files',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.write('pubspec.yaml', kConfigFormatFix);

      // Stage invalid file
      await project.fs.write('lib/main.dart', kInvalidDart);
      await project.git.run(['add', 'lib/main.dart']);
      final status = await project.git.status();

      // Run lint_staged to automatically format the file and commit formatted files
      await expectLater(project.gitCommit(), throwsIntegrationTestError);

      // Nothing was wrong so the empty commit is created
      expect(await project.git.commitCount, equals(1));
      expect(await project.git.lastCommit, contains('initial commit'));
      expect(await project.git.status(), equals(status));
      expect(await project.fs.read('lib/main.dart'), equals(kInvalidDart));
    });

    test('clears unstaged changes when linter applies same changes', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.append('pubspec.yaml', kConfigFormatFix);

      // Stage unformatted file
      await project.fs.append(
        'lib/main.dart',
        kUnFormattedDart,
      );
      await project.git.run(['add', 'lib/main.dart']);

      // Replace unformatted file with formatted but do not stage changes
      await project.fs.remove('lib/main.dart');
      await project.fs.append('lib/main.dart', kFormattedDart);

      // Run lint_staged to automatically format the file and commit formatted files
      await project.gitCommit();

      // Nothing was wrong so the empty commit is created
      expect(await project.git.commitCount, equals(2));
      expect(await project.git.lastCommit, contains('test'));

      // Latest commit contains pretty file
      // `git show` strips empty line from here here
      expect(await project.git.show(['HEAD:lib/main.dart']),
          equals(kFormattedDart.trim()));

      // Nothing is staged
      expect(await project.git.status(), contains('nothing added to commit'));

      // File is pretty, and has been edited
      expect(await project.fs.read('lib/main.dart'), equals(kFormattedDart));
    });

    test('runs chunked tasks when necessary', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.write('pubspec.yaml', kConfigFormatExit);

      // Stage two files
      await project.fs.write('lib/main.dart', kFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);
      await project.fs.write('lib/foo.dart', kFormattedDart);
      await project.git.run(['add', 'lib/foo.dart']);

      // Run lint_staged to automatically format the file and commit formatted files
      // Set maxArgLength low enough so that chunking is used
      await project.gitCommit(maxArgLength: 10);

      // Nothing was wrong so the empty commit is created
      expect(await project.git.commitCount, equals(2));
      expect(await project.git.lastCommit, contains('test'));
      expect(await project.fs.read('lib/main.dart'), equals(kFormattedDart));
      expect(await project.fs.read('lib/foo.dart'), equals(kFormattedDart));
    });

    test('fails when backup stash is missing', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();
      final config = '''lint_staged:
  'lib/**.dart': git stash drop
''';
      await project.fs.write('pubspec.yaml', config);

      // Stage two files
      await project.fs.write('lib/main.dart', kFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);

      // Run lint_staged to automatically format the file and commit formatted files
      // Set maxArgLength low enough so that chunking is used
      expect(project.gitCommit(maxArgLength: 10), throwsIntegrationTestError);
    });

    test('works when a branch named stash exists', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();
      await project.fs.write('pubspec.yaml', kConfigFormatExit);

      // create a new branch called stash
      await project.git.run(['branch', 'stash']);

      // Stage two files
      await project.fs.write('lib/main.dart', kFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);

      // Run lint_staged to automatically format the file and commit formatted file
      await project.gitCommit();

      // Nothing is wrong, so a new commit is created and file is pretty
      expect(await project.git.commitCount, equals(2));
      expect(await project.git.lastCommit, contains('test'));
      expect(await project.fs.read('lib/main.dart'), equals(kFormattedDart));
    });

    test('ignores files given in pubspec.yaml', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.write('pubspec.yaml', kConfigFormatFixWithIgnore);

      // Stage multi unformatted files
      await project.fs.write('lib/main.dart', kUnFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);

      await project.fs.write('lib/foo.g.dart', kUnFormattedDart);
      await project.git.run(['add', 'lib/foo.g.dart']);

      // Run lint_staged to automatically format the file and commit formatted files
      await project.gitCommit();

      // main.dart should be formatted, while foo.g.dart should not
      expect(await project.git.commitCount, equals(2));
      expect(await project.git.lastCommit, contains('test'));
      expect(await project.fs.read('lib/main.dart'), equals(kFormattedDart));
      expect(await project.fs.read('lib/foo.g.dart'), equals(kUnFormattedDart));
    });
  });
}
