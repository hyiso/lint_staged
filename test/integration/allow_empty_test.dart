import 'package:lint_staged/src/file.dart';
import 'package:lint_staged/src/git.dart';
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged --allow-empty', () {
    test(
        'fails when task reverts staged changes without `--allow-empty`, to prevent an empty git commit',
        () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatFix, workingDirectory: dir);

      // Create and commit a pretty file without running lint_staged
      // This way the file will be available for the next step
      await writeFile('lib/main.dart', kFormattedDart, workingDirectory: dir);
      await execGit(['add', '.'], workingDirectory: dir);
      await execGit(['commit', '-m committed pretty file'],
          workingDirectory: dir);

      // Edit file to be ugly
      await removeFile('lib/main.dart', workingDirectory: dir);
      await writeFile('lib/main.dart', kUnFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);

      // Run lint_staged to automatically format the file
      // Since prettier reverts all changes, the commit should fail
      await expectLater(gitCommit(workingDirectory: dir), throwsException);

      // Something was wrong so the repo is returned to original state
      expect(
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir),
          equals('2'));
      expect(await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir),
          contains('committed pretty file'));
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kUnFormattedDart));
    });

    test(
        'creates commit when task reverts staged changed and --allow-empty is used',
        () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatFix, workingDirectory: dir);

      // Create and commit a pretty file without running lint_staged
      // This way the file will be available for the next step
      await writeFile('lib/main.dart', kFormattedDart, workingDirectory: dir);
      await execGit(['add', '.'], workingDirectory: dir);
      await execGit(['commit', '-m committed pretty file'],
          workingDirectory: dir);

      // Edit file to be unformatted
      await removeFile('lib/main.dart', workingDirectory: dir);
      await writeFile('lib/main.dart', kUnFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);

      // Run lint_staged to automatically format the file
      // Here we also pass '--allow-empty' to gitCommit because this part is not the full lint_staged
      await expectLater(
          gitCommit(
              allowEmpty: true,
              gitCommitArgs: ['-m test', '--allow-empty'],
              workingDirectory: dir),
          completes);

      // Nothing was wrong so the empty commit is created
      expect(
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir),
          equals('3'));
      expect(await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir),
          contains('test'));
      expect(await execGit(['diff', '-1'], workingDirectory: dir), equals(''));
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kFormattedDart));
    });
  });
}
