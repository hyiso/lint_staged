import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('does not resurrect removed files due to git bug when tasks pass',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.writeFile('pubspec.yaml', kConfigFormatExit);

      await project.removeFile('README.md'); // Remove file from previous commit
      await project.writeFile('lib/main.dart', kFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);

      await project.gitCommit();

      expect(await project.existsFile('README.md'), isFalse);
    });

    test('does not resurrect removed files in complex case', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.writeFile('pubspec.yaml', kConfigFormatExit);

      // Add file to index, and remove it from disk
      await project.writeFile('lib/main.dart', kFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);
      await project.removeFile('lib/main.dart');

      // Rename file in index, and remove it from disk
      final readme = await project.readFile('README.md');
      await project.removeFile('README.md');
      await project.execGit(['add', 'README.md']);
      await project.writeFile('README_NEW.md', readme!);
      await project.execGit(['add', 'README_NEW.md']);
      await project.removeFile('README_NEW.md');

      expect(
          await project.execGit(['status', '--porcelain']),
          contains('RD README.md -> README_NEW.md\n'
              'AD lib/main.dart\n'
              '?? pubspec.yaml'));

      await project.gitCommit();

      expect(
          await project.execGit(['status', '--porcelain']),
          contains(' D README_NEW.md\n'
              ' D lib/main.dart\n'
              '?? pubspec.yaml'));

      expect(await project.existsFile('lib/main.dart'), isFalse);
      expect(await project.existsFile('README_NEW.md'), isFalse);
    });

    test('does not resurrect removed files due to git bug when tasks fail',
        () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      await project.writeFile('pubspec.yaml', kConfigFormatExit);

      await project.removeFile('README.md'); // Remove file from previous commit
      await project.writeFile('lib/main.dart', kUnFormattedDart);
      await project.execGit(['add', 'lib/main.dart']);

      expect(
          await project.execGit(['status', '--porcelain']),
          contains(' D README.md\n'
              'A  lib/main.dart\n'
              '?? pubspec.yaml'));

      await expectLater(project.gitCommit(allowEmpty: true), throwsException);

      expect(
          await project.execGit(['status', '--porcelain']),
          contains(' D README.md\n'
              'A  lib/main.dart\n'
              '?? pubspec.yaml'));

      expect(await project.existsFile('README.md'), isFalse);
    });
  });
}
