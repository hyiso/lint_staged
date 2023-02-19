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

      // Add untracked files
      await project.appendFile('lib/untracked.dart', kFormattedDart);
      await project.appendFile('.gitattributes', 'binary\n');
      await project.writeFile('binary', 'Hello, World!');

      // Run lint_staged with `dart format --set-exit-if-changed` and commit formatted file
      await project.gitCommit();

      // Nothing is wrong, so a new commit is created
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('2'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('test'));
      expect(await project.readFile('lib/main.dart'), equals(kFormattedDart));
      expect(
          await project.readFile('lib/untracked.dart'), equals(kFormattedDart));
      expect(await project.readFile('binary'), equals('Hello, World!'));
    });
    test('ingores untracked files when task fails', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.appendFile('pubspec.yaml', kConfigFormatExit);

      // Stage unfixable file
      await project.appendFile('lib/main.dart', kInvalidDart);
      await project.execGit(['add', 'lib/main.dart']);

      // Add untracked files
      await project.appendFile('lib/untracked.dart', kFormattedDart);
      await project.appendFile('.gitattributes', 'binary\n');
      await project.writeFile('binary', 'Hello, World!');

      // Run lint_staged with `dart format --set-exit-if-changed` and commit formatted file
      expectLater(project.gitCommit(), throwsException);

      // Something was wrong so the repo is returned to original state
      expect(
          await project.execGit(['rev-list', '--count', 'HEAD']), equals('1'));
      expect(await project.execGit(['log', '-1', '--pretty=%B']),
          contains('initial commit'));
      expect(await project.readFile('lib/main.dart'), equals(kInvalidDart));
      expect(
          await project.readFile('lib/untracked.dart'), equals(kFormattedDart));
      expect(await project.readFile('binary'), equals('Hello, World!'));
    });
  });
}
