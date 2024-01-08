import 'dart:io' show Process, ProcessException, ProcessResult;
import 'dart:math';

import 'package:ansi/ansi.dart';
import 'package:path/path.dart';
import 'package:verbose/verbose.dart';

final _verbose = Verbose('lit_staged:git');

class Git {
  final String? workingDirectory;
  final List<String> _diff;
  final String? diffFilter;

  Git({this.workingDirectory, List<String> diff = const [], this.diffFilter})
      : _diff = diff;

  String? _gitdir;
  String get gitdir =>
      _gitdir ??= Process.runSync('git', ['rev-parse', '--git-dir'],
              workingDirectory: workingDirectory)
          .stdout
          .toString()
          .trim();

  String? _currentBranch;
  String get currentBranch => _currentBranch ??= Process.runSync(
          'git', ['rev-parse', '--abbrev-ref', 'HEAD'],
          workingDirectory: workingDirectory)
      .stdout
      .toString()
      .trim();

  Future<String> status([List<String> args = const []]) async =>
      _stdout(['status', ...args]);

  Future<String> show([List<String> args = const []]) async =>
      _stdout(['show', ...args]);

  Future<String> diff([List<String> args = const []]) async =>
      _stdout(['diff', ...args]);

  Future<ProcessResult> run(List<String> args) async {
    final result = await Process.run('git', [..._kNoSubmoduleRecurse, ...args],
        workingDirectory: workingDirectory);
    final messsages = ['git ${args.join(' ')}'];
    if (result.stderr.toString().trim().isNotEmpty) {
      messsages.add(grey(result.stderr.toString().trim()));
    }
    if (result.stdout.toString().trim().isNotEmpty) {
      messsages.add(grey(result.stdout.toString().trim()));
    }
    _verbose(messsages.join('\n'));
    if (result.exitCode != 0) {
      throw ProcessException(
          'git', args, messsages.join('\n'), result.exitCode);
    }
    return result;
  }

  Future<String> _stdout(List<String> args) async {
    final result = await run(args);
    String output = result.stdout as String;
    if (output.endsWith('\n')) {
      output = output.replaceFirst(RegExp(r'(\n)+$'), '');
    }
    return output;
  }

  Future<List<String>> get stagedFiles async {
    final args = getDiffArgs(diff: _diff, diffFilter: diffFilter);
    final output = await _stdout(args);
    final files = parseGitZOutput(output).toList();
    _verbose('Staged files: $files');
    return files;
  }

  ///
  /// Get a list of all files with both staged and unstaged modifications.
  /// Renames have special treatment, since the single status line includes
  /// both the "from" and "to" filenames, where "from" is no longer on disk.
  ///
  Future<List<String>> get partiallyStagedFiles async {
    final status = await _stdout(['status', '-z']);
    if (status.isEmpty) {
      return [];
    }

    ///
    /// See https://git-scm.com/docs/git-status#_short_format
    /// Entries returned in machine format are separated by a NUL character.
    /// The first letter of each entry represents current index status,
    /// and second the working tree. Index and working tree status codes are
    /// separated from the file name by a space. If an entry includes a
    /// renamed file, the file names are separated by a NUL character
    /// (e.g. `to`\0`from`)
    ///
    final files = status
        .split(RegExp(r'\x00(?=[ AMDRCU?!]{2} |$)'))
        .where((line) {
          if (line.length > 2) {
            final index = line[0];
            final workingTree = line[1];
            return index != ' ' &&
                workingTree != ' ' &&
                index != '?' &&
                workingTree != '?';
          }
          return false;
        })
        .map((line) => line.substring(min(3, line.length)))

        /// Remove first three letters (index, workingTree, and a whitespace)
        .where((e) => e.isNotEmpty)

        /// Filter empty string
        .toList();
    _verbose('Found partially staged files: $files');
    return files;
  }

  Future<String> get lastCommit async {
    final output = await _stdout(['log', '-1', '--pretty=%B']);
    return output.trim();
  }

  Future<int> get commitCount async {
    final output = await _stdout(['rev-list', '--count', 'HEAD']);
    return int.parse(output.trim());
  }

  Future<List<String>> get hashes async {
    final output = await _stdout(['log', '--format=format:%H']);
    return output.trim().split('\n');
  }

  Future<List<String>> get stashes async {
    final output = await _stdout(['stash', 'list']);
    return output.trim().split('\n');
  }

  Future<List<String>> get deletedFiles async {
    final output = await _stdout(['ls-files', '--deleted']);
    final files =
        output.split('\n').where((line) => line.trim().isNotEmpty).toList();
    _verbose('Deleted files: $files');
    return files;
  }

  /// The `stash create` command creates a dangling commit without removing any files,
  Future<String> createStash() async {
    final output = await _stdout(['stash', 'create']);
    return output.trim();
  }

  Future<String> storeStash(String stash, {required String message}) async {
    final output =
        await _stdout(['stash', 'store', '--quiet', '-m', message, stash]);
    return output.trim();
  }
}

///
/// Get git diff arguments
///
List<String> getDiffArgs({
  List<String> diff = const [],
  String? diffFilter,
}) {
  ///
  /// Docs for --diff-filter option:
  /// @see https://git-scm.com/docs/git-diff#Documentation/git-diff.txt---diff-filterACDMRTUXB82308203
  ///
  final diffFilterArgs = diffFilter != null ? diffFilter.trim() : 'ACMR';

  /// Use `--diff branch1...branch2` or `--diff="branch1,branch2", or fall back to default staged files
  final diffArgs = diff.isNotEmpty ? diff : ['--staged'];

  /// Docs for -z option:
  /// @see https://git-scm.com/docs/git-diff#Documentation/git-diff.txt--z
  return [
    'diff',
    '--name-only',
    '-z',
    '--diff-filter=$diffFilterArgs',
    ...diffArgs
  ];
}

/// Explicitly never recurse commands into submodules, overriding local/global configuration.
/// @see https://git-scm.com/docs/git-config#Documentation/git-config.txt-submodulerecurse
///
const _kNoSubmoduleRecurse = ['-c', 'submodule.recurse=false'];

///
/// Return array of strings split from the output of `git <something> -z`.
/// With `-z`, git prints `fileA\u0000fileB\u0000fileC\u0000` so we need to
/// remove the last occurrence of `\u0000` before splitting
///
List<String> parseGitZOutput(String input) {
  return input.isEmpty
      ? []
      : input.replaceFirst(RegExp(r'\u0000$'), '').split('\u0000');
}
