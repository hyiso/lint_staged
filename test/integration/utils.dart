import 'dart:io';
import 'package:lint_staged/lint_staged.dart';
import 'package:lint_staged/src/file.dart' as file;
import 'package:lint_staged/src/git.dart' as git;
import 'package:path/path.dart';

class IntegrationProject {
  final String dir;

  IntegrationProject()
      : dir = join(Directory.systemTemp.path, 'tmp',
            'husky_test_${DateTime.now().microsecondsSinceEpoch}');

  Future<void> setup({bool initialCommit = true}) async {
    /// Git init
    await git.execGit(['init', dir]);
    await git.execGit(['branch', '-M', 'main']);

    /// Git config
    await execGit(['config', 'user.name', 'test']);
    await execGit(['config', 'user.email', 'test@example.com']);
    await execGit(['config', 'commit.gpgsign', 'false']);
    await execGit(['config', 'merge.conflictstyle', 'merge']);

    if (initialCommit) {
      await _initialCommit();
    }
  }

  Future<void> _initialCommit() async {
    await appendFile('README.md', '# Test\n');
    await execGit(['add', 'README.md']);
    await execGit(['commit', '-m initial commit']);
  }

  Future<String> execGit(List<String> args) =>
      git.execGit(args, workingDirectory: dir);

  Future<void> gitCommit({
    bool allowEmpty = false,
    int maxArgLength = 0,
    List<String>? gitCommitArgs,
    String? workingDirectory,
  }) async {
    final passed = await lintStaged(
        maxArgLength: maxArgLength,
        allowEmpty: allowEmpty,
        workingDirectory: workingDirectory ?? dir);
    if (!passed) {
      throw Exception('lint_staged not passed!');
    }
    final commitArgs = gitCommitArgs ?? ['-m test'];
    await git.execGit(['commit', ...commitArgs],
        workingDirectory: workingDirectory ?? dir);
  }

  Future<void> appendFile(String filename, String content) =>
      file.appendFile(filename, content, workingDirectory: dir);

  Future<void> writeFile(
    String filename,
    String content,
  ) =>
      file.writeFile(filename, content, workingDirectory: dir);

  Future<void> removeFile(String filename) =>
      file.removeFile(filename, workingDirectory: dir);

  Future<String?> readFile(String filename) =>
      file.readFile(filename, workingDirectory: dir);

  Future<bool> existsFile(String filename) =>
      File(join(dir, filename)).exists();
}
