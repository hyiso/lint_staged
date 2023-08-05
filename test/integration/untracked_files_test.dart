import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('ignores untracked files', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.append('pubspec.yaml', kConfigFormatExit);
      // Stage pretty file
      await project.fs.append('lib/main.dart', kFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);

      // Add untracked files
      await project.fs.append('lib/untracked.dart', kFormattedDart);
      await project.fs.append('.gitattributes', 'binary\n');
      await project.fs.write('binary', 'Hello, World!');

      // Run lint_staged with `dart format --set-exit-if-changed` and commit formatted file
      await project.gitCommit();

      // Nothing is wrong, so a new commit is created
      expect(await project.git.commitCount, equals(2));
      expect(await project.git.lastCommit, contains('test'));
      expect(await project.fs.read('lib/main.dart'), equals(kFormattedDart));
      expect(
          await project.fs.read('lib/untracked.dart'), equals(kFormattedDart));
      expect(await project.fs.read('binary'), equals('Hello, World!'));
    });
    test('ingores untracked files when task fails', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.append('pubspec.yaml', kConfigFormatExit);

      // Stage unfixable file
      await project.fs.append('lib/main.dart', kInvalidDart);
      await project.git.run(['add', 'lib/main.dart']);

      // Add untracked files
      await project.fs.append('lib/untracked.dart', kFormattedDart);
      await project.fs.append('.gitattributes', 'binary\n');
      await project.fs.write('binary', 'Hello, World!');

      // Run lint_staged with `dart format --set-exit-if-changed` and commit formatted file
      expectLater(project.gitCommit(), throwsException);

      // Something was wrong so the repo is returned to original state
      expect(await project.git.commitCount, equals(1));
      expect(await project.git.lastCommit, contains('initial commit'));
      expect(await project.fs.read('lib/main.dart'), equals(kInvalidDart));
      expect(
          await project.fs.read('lib/untracked.dart'), equals(kFormattedDart));
      expect(await project.fs.read('binary'), equals('Hello, World!'));
    });
  });
}
