import 'dart:io';

import 'package:lint_staged/src/file.dart';
import 'package:lint_staged/src/git.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('does not resurrect removed files due to git bug when tasks pass',
        () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatExit, workingDirectory: dir);

      await removeFile('README.md',
          workingDirectory: dir); // Remove file from previous commit
      await writeFile('lib/main.dart', kFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);

      await gitCommit(workingDirectory: dir);

      expect(await File(join(dir, 'README.md')).exists(), isFalse);
    });

    test('does not resurrect removed files in complex case', () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatExit, workingDirectory: dir);

      // Add file to index, and remove it from disk
      await writeFile('lib/main.dart', kFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);
      await removeFile('lib/main.dart', workingDirectory: dir);

      // Rename file in index, and remove it from disk
      final readme = await readFile('README.md', workingDirectory: dir);
      await removeFile('README.md', workingDirectory: dir);
      await execGit(['add', 'README.md'], workingDirectory: dir);
      await writeFile('README_NEW.md', readme!, workingDirectory: dir);
      await execGit(['add', 'README_NEW.md'], workingDirectory: dir);
      await removeFile('README_NEW.md', workingDirectory: dir);

      expect(
          await execGit(['status', '--porcelain'], workingDirectory: dir),
          contains('RD README.md -> README_NEW.md\n'
              'AD lib/main.dart\n'
              '?? pubspec.yaml'));

      await gitCommit(workingDirectory: dir);

      expect(
          await execGit(['status', '--porcelain'], workingDirectory: dir),
          contains(' D README_NEW.md\n'
              ' D lib/main.dart\n'
              '?? pubspec.yaml'));

      expect(await File(join(dir, 'lib/main.dart')).exists(), isFalse);
      expect(await File(join(dir, 'README_NEW.md')).exists(), isFalse);
    });

    test('does not resurrect removed files due to git bug when tasks fail',
        () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatExit, workingDirectory: dir);

      await removeFile('README.md',
          workingDirectory: dir); // Remove file from previous commit
      await writeFile('lib/main.dart', kUnFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);

      expect(
          await execGit(['status', '--porcelain'], workingDirectory: dir),
          contains(' D README.md\n'
              'A  lib/main.dart\n'
              '?? pubspec.yaml'));

      final commit = gitCommit(workingDirectory: dir, allowEmpty: true);

      await expectLater(commit, throwsException);

      expect(
          await execGit(['status', '--porcelain'], workingDirectory: dir),
          contains(' D README.md\n'
              'A  lib/main.dart\n'
              '?? pubspec.yaml'));

      expect(await File(join(dir, 'README.md')).exists(), isFalse);
    });
  });
}
