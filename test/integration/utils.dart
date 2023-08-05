import 'dart:io';
import 'package:lint_staged/lint_staged.dart';
import 'package:lint_staged/src/fs.dart';
import 'package:lint_staged/src/git.dart';
import 'package:path/path.dart';

String _temp() => join(Directory.systemTemp.path, 'tmp',
    'husky_test_${DateTime.now().microsecondsSinceEpoch}');

class IntegrationProject {
  final String path;
  late final Git git = Git(workingDirectory: path);
  late final fs = FileSystem(path);
  IntegrationProject([String? directory]) : path = directory ?? _temp();

  Future<void> setup({bool initialCommit = true}) async {
    /// Git init
    await Process.run('git', ['init', path]);

    /// Git config
    await config();

    if (initialCommit) {
      await _initialCommit();
    }
  }

  Future<void> config() async {
    await git.run(['config', 'user.name', 'test']);
    await git.run(['config', 'user.email', 'test@example.com']);
    await git.run(['config', 'commit.gpgsign', 'false']);
    await git.run(['config', 'merge.conflictstyle', 'merge']);
  }

  Future<void> _initialCommit() async {
    await fs.appendFile('README.md', '# Test\n');
    await git.run(['add', 'README.md']);
    await git.run(['commit', '-m initial commit']);
  }

  Future<void> gitCommit({
    bool allowEmpty = false,
    int maxArgLength = 0,
    List<String>? gitCommitArgs,
  }) async {
    final passed = await lintStaged(
        maxArgLength: maxArgLength,
        allowEmpty: allowEmpty,
        workingDirectory: path);
    if (!passed) {
      throw Exception('lint_staged not passed!');
    }
    final commitArgs = gitCommitArgs ?? ['-m test'];
    await git.run(['commit', ...commitArgs]);
  }
}
