import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('does not resurrect removed files due to git bug when tasks pass',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.write('pubspec.yaml', kConfigFormatExit);

      await project.fs.remove('README.md'); // Remove file from previous commit
      await project.fs.write('lib/main.dart', kFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);

      await project.gitCommit();

      expect(await project.fs.exists('README.md'), isFalse);
    });

    test('does not resurrect removed files in complex case', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.write('pubspec.yaml', kConfigFormatExit);

      // Add file to index, and remove it from disk
      await project.fs.write('lib/main.dart', kFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);
      await project.fs.remove('lib/main.dart');

      // Rename file in index, and remove it from disk
      final readme = await project.fs.read('README.md');
      await project.fs.remove('README.md');
      await project.git.run(['add', 'README.md']);
      await project.fs.write('README_NEW.md', readme!);
      await project.git.run(['add', 'README_NEW.md']);
      await project.fs.remove('README_NEW.md');

      expect(
          await project.git.status(['--porcelain']),
          contains('RD README.md -> README_NEW.md\n'
              'AD lib/main.dart\n'
              '?? pubspec.yaml'));

      await project.gitCommit();

      expect(
          await project.git.status(['--porcelain']),
          contains(' D README_NEW.md\n'
              ' D lib/main.dart\n'
              '?? pubspec.yaml'));

      expect(await project.fs.exists('lib/main.dart'), isFalse);
      expect(await project.fs.exists('README_NEW.md'), isFalse);
    });

    test('does not resurrect removed files due to git bug when tasks fail',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.write('pubspec.yaml', kConfigFormatExit);

      await project.fs.remove('README.md'); // Remove file from previous commit
      await project.fs.write('lib/main.dart', kUnFormattedDart);
      await project.git.run(['add', 'lib/main.dart']);

      expect(
          await project.git.status(['--porcelain']),
          contains(' D README.md\n'
              'A  lib/main.dart\n'
              '?? pubspec.yaml'));

      await expectLater(
          project.gitCommit(allowEmpty: true), throwsIntegrationTestError);

      expect(
          await project.git.status(['--porcelain']),
          contains(' D README.md\n'
              'A  lib/main.dart\n'
              '?? pubspec.yaml'));

      expect(await project.fs.exists('README.md'), isFalse);
    });
  });
}
