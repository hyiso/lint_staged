import 'dart:io';

import 'package:lint_staged/src/file.dart';
import 'package:lint_staged/src/git.dart';
import 'package:path/path.dart' show join;
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('handles git submodules', () async {
      final project = IntegrationProject();
      print('dir: ${project.dir}');
      await project.setup();

      // create a new repo for the git submodule to a temp path
      String submoduleDir = join(project.dir, 'submodule_temp');
      if (!await Directory(submoduleDir).exists()) {
        await Directory(submoduleDir).create(recursive: true);
      }
      await execGit(['init', submoduleDir]);
      await execGit(['config', 'user.name', '"test"'],
          workingDirectory: submoduleDir);
      await execGit(['config', 'user.email', '"test@test.com"'],
          workingDirectory: submoduleDir);
      await appendFile('README.md', '# Test\n', workingDirectory: submoduleDir);
      await execGit(['add', 'README.md'], workingDirectory: submoduleDir);
      await execGit(['commit', '-m initial commit'],
          workingDirectory: submoduleDir);

      // Add the newly-created repo as a submodule in a new path.
      // This simulates adding it from a remote. By default file protocol is not allowed,
      // see https://git-scm.com/docs/git-config#Documentation/git-config.txt-protocolallow
      await project.execGit([
        '-c',
        'protocol.file.allow=always',
        'submodule',
        'add',
        '--force',
        './submodule_temp',
        './submodule',
      ]);
      submoduleDir = join(project.dir, 'submodule');
      // Set these again for Windows git in CI
      await execGit(['config', 'user.name', '"test"'],
          workingDirectory: submoduleDir);
      await execGit(['config', 'user.email', '"test@test.com"'],
          workingDirectory: submoduleDir);
      await writeFile('pubspec.yaml', kConfigFormatExit,
          workingDirectory: submoduleDir);

      // Stage pretty file
      await appendFile('lib/main.dart', kFormattedDart,
          workingDirectory: submoduleDir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: submoduleDir);

      // Run lint-staged with `prettier --list-different` and commit pretty file
      await project.gitCommit(workingDirectory: submoduleDir);

      // Nothing is wrong, so a new commit is created
      expect(
          await execGit(['rev-list', '--count', 'HEAD'],
              workingDirectory: submoduleDir),
          equals('2'));
      expect(
          await execGit(['log', '-1', '--pretty=%B'],
              workingDirectory: submoduleDir),
          contains('test'));
      expect(await readFile('lib/main.dart', workingDirectory: submoduleDir),
          equals(kFormattedDart));
    });
  });
}
