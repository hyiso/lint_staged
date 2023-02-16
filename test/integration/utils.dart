import 'dart:io';
import 'package:lint_staged/lint_staged.dart';
import 'package:lint_staged/src/file.dart';
import 'package:lint_staged/src/git.dart';
import 'package:path/path.dart';

String tmp() {
  final tmp = Directory.systemTemp.path;
  return join(
      tmp, 'tmp', 'husky_test_${DateTime.now().millisecondsSinceEpoch}');
}

Future<void> setupGit(String dir, {bool withInitialCommit = true}) async {
  /// Git init
  await execGit(['init', dir]);

  /// Git config
  await execGit(['config', 'user.name', 'test'], workingDirectory: dir);
  await execGit(['config', 'user.email', 'test@example.com'],
      workingDirectory: dir);
  await execGit(['config', 'commit.gpgsign', 'false'], workingDirectory: dir);
  await execGit(['config', 'merge.conflictstyle', 'merge']);

  if (withInitialCommit) {
    await initialCommit(dir);
  }
}

Future<void> initialCommit(String workingDirectory) async {
  await appendFile('README.md', '# Test\n', workingDirectory: workingDirectory);
  await execGit(['add', 'README.md'], workingDirectory: workingDirectory);
  await execGit(['commit', '-m initial commit'],
      workingDirectory: workingDirectory);
}

Future<void> gitCommit({
  bool allowEmpty = false,
  List<String>? gitCommitArgs,
  required String workingDirectory,
}) async {
  final passed = await lintStaged(
      allowEmpty: allowEmpty, workingDirectory: workingDirectory);
  if (!passed) {
    throw Exception('');
  }
  final commitArgs = gitCommitArgs ?? ['-m test'];
  await execGit(['commit', ...commitArgs], workingDirectory: workingDirectory);
}
