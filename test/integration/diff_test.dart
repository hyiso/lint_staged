import 'package:lint_staged/lint_staged.dart';
import 'package:lint_staged/src/file.dart';
import 'package:lint_staged/src/git.dart';
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('supports overriding file list using --diff', () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatExit, workingDirectory: dir);

      // Commit unformatted file
      await writeFile('lib/main.dart', kUnFormattedDart, workingDirectory: dir);
      await execGit(['add', '.'], workingDirectory: dir);
      await execGit(['commit', '-m unformatted'], workingDirectory: dir);

      final hashes =
          (await execGit(['log', '--format=format:%H'], workingDirectory: dir))
              .trim()
              .split('\n');
      expect(hashes.length, 2);

      // Run lint_staged with `--diff` between the two commits.
      // Nothing is staged at this point, so don't run `gitCommit`
      final passed = await lintStaged(
        diff: ['${hashes[1]}..${hashes[0]}'],
        stash: false,
        workingDirectory: dir,
      );
      // lint_staged failed because commit diff contains unformatted file
      expect(passed, isFalse);
    });

    test('supports overriding default --diff-filter', () async {
      final dir = tmp();
      print('dir: $dir');
      await setupGit(dir);

      await writeFile('pubspec.yaml', kConfigFormatExit, workingDirectory: dir);

      // Stage unformatted file
      await writeFile('lib/main.dart', kUnFormattedDart, workingDirectory: dir);
      await execGit(['add', '.'], workingDirectory: dir);

      // Run lint-staged with `--diff-filter=D` to include only deleted files.
      final passed = await lintStaged(
        diffFilter: 'D',
        stash: false,
        workingDirectory: dir,
      );
      // lint_staged passed because no matching (deleted) files
      expect(passed, isTrue);
    });
  });
}
