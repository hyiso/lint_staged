import 'package:lint_staged/lint_staged.dart';
import 'package:test/test.dart';

import '__fixtures__/config.dart';
import '__fixtures__/file.dart';
import 'utils.dart';

void main() {
  group('lint_staged', () {
    test('supports overriding file list using --diff', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.writeFile('pubspec.yaml', kConfigFormatExit);

      // Commit unformatted file
      await project.fs.writeFile('lib/main.dart', kUnFormattedDart);
      await project.git.run(['add', '.']);
      await project.git.run(['commit', '-m unformatted']);

      final hashes = (await project.git.stdout(['log', '--format=format:%H']))
          .trim()
          .split('\n');
      expect(hashes.length, 2);

      // Run lint_staged with `--diff` between the two commits.
      // Nothing is staged at this point, so don't run `gitCommit`
      final passed = await lintStaged(
        diff: ['${hashes[1]}..${hashes[0]}'],
        stash: false,
        workingDirectory: project.path,
      );
      // lint_staged failed because commit diff contains unformatted file
      expect(passed, isFalse);
    });

    test('supports overriding default --diff-filter', () async {
      final project = IntegrationProject();
      print('dir: ${project.path}');
      await project.setup();

      await project.fs.writeFile('pubspec.yaml', kConfigFormatExit);

      // Stage unformatted file
      await project.fs.writeFile('lib/main.dart', kUnFormattedDart);
      await project.git.run(['add', '.']);

      // Run lint_staged with `--diff-filter=D` to include only deleted files.
      final passed = await lintStaged(
        diffFilter: 'D',
        stash: false,
        workingDirectory: project.path,
      );
      // lint_staged passed because no matching (deleted) files
      expect(passed, isTrue);
    });
  });
}
