import 'package:lint_staged/src/file.dart';
import 'package:lint_staged/src/git.dart';
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('--allow-empty', () {
    test(
        'fails when task reverts staged changes without `--allow-empty`, to prevent an empty git commit',
        () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kFormatConfig, workingDirectory: dir);

      // Create and commit a pretty file without running lint-staged
      // This way the file will be available for the next step
      await writeFile('lib/main.dart', kFormattedDart, workingDirectory: dir);
      await execGit(['add', '.'], workingDirectory: dir);
      await execGit(['commit', '-m committed pretty file'],
          workingDirectory: dir);

      // Edit file to be ugly
      await removeFile('lib/main.dart', workingDirectory: dir);
      await writeFile('lib/main.dart', kUnFormattedDart, workingDirectory: dir);
      await execGit(['add', 'lib/main.dart'], workingDirectory: dir);
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kUnFormattedDart));

      // Run lint_staged to automatically format the file
      // Since prettier reverts all changes, the commit should fail
      await expectLater(
          () async => gitCommit(workingDirectory: dir), throwsException);

      // Something was wrong so the repo is returned to original state
      final revCount =
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir);
      expect(revCount.trim(), equals('2'));
      final lastCommitMsg =
          await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir);
      expect(lastCommitMsg.trim(), equals('committed pretty file'));
      expect(await readFile('lib/main.dart', workingDirectory: dir),
          equals(kUnFormattedDart));
    });

    test(
        'creates commit when task reverts staged changed and --allow-empty is used',
        () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kFormatConfig, workingDirectory: dir);

      // Create and commit a pretty file without running lint-staged
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
      // Here we also pass '--allow-empty' to gitCommit because this part is not the full lint-staged
      final commit = gitCommit(
          allowEmpty: true,
          gitCommitArgs: ['-m test', '--allow-empty'],
          workingDirectory: dir);
      await expectLater(commit, completes);

      // Nothing was wrong so the empty commit is created
      final revCount =
          await execGit(['rev-list', '--count', 'HEAD'], workingDirectory: dir);
      expect(revCount.trim(), equals('3'));
      final lastCommitMsg =
          await execGit(['log', '-1', '--pretty=%B'], workingDirectory: dir);
      expect(lastCommitMsg.trim(), equals('test'));
      final diff = await execGit(['diff', '-1'], workingDirectory: dir);
      expect(diff.trim(), equals(''));
      final content = await readFile('lib/main.dart', workingDirectory: dir);
      expect(content, equals(kFormattedDart));
    });
  });
}
