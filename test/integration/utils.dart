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

  IntegrationProject.dirctory(this.dir);

  Future<void> setup({bool initialCommit = true}) async {
    /// Git init
    await git.execGit(['init', dir]);

    /// Git config
    await config(dir);

    if (initialCommit) {
      await _initialCommit();
    }
  }

  Future<void> config(String dir) async {
    await git.execGit(['config', 'user.name', 'test'], workingDirectory: dir);
    await git.execGit(['config', 'user.email', 'test@example.com'],
        workingDirectory: dir);
    await git
        .execGit(['config', 'commit.gpgsign', 'false'], workingDirectory: dir);
    await git.execGit(['config', 'merge.conflictstyle', 'merge'],
        workingDirectory: dir);
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
