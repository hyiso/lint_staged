import 'dart:math';

import 'package:lint_staged/src/git.dart';

/// In git status machine output, renames are presented as `to`NUL`from`
/// When diffing, both need to be taken into account, but in some cases on the `to`.
final _renameRegex = RegExp(r'\x00');

/// From list of files, split renames and flatten into two files `to`NUL`from`.
List<String> processRenames(List<String> files, [bool includeRenameFrom = true]) {
  return files.fold([], (flattened, file) {
    if (_renameRegex.hasMatch(file)) {
      /// first is to, last is from
      final rename = file.split(_renameRegex);
      if (includeRenameFrom) {
        flattened.add(rename.last);
      }
      flattened.add(rename.first);
    } else {
      flattened.add(file);
    }
    return flattened;
  });
}

class GitWorkflow {
  final bool allowEmpty;
  final String? gitDir;

  late List<String> partiallyStagedFiles;

  GitWorkflow({
    this.allowEmpty = false,
    this.gitDir,
  });

  ///
  /// Get a list of all files with both staged and unstaged modifications.
  /// Renames have special treatment, since the single status line includes
  /// both the "from" and "to" filenames, where "from" is no longer on disk.
  ///
  Future<List<String>> getPartiallyStagedFiles() async {
    final status = await execGit(['status', '-z'], workingDirectory: gitDir);
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
    return status.split(RegExp(r'\x00(?=[ AMDRCU?!]{2} |$)'))
      .where((line) {
        if (line.length > 2) {
          final index = line[0];
          final workingTree = line[1];
          return index != ' ' && workingTree!= ' ' && index != '?' && workingTree != '?';
        }
        return false;
      })
      .map((line) => line.substring(min(3, line.length))) /// Remove first three letters (index, workingTree, and a whitespace)
      .where((e) => e.isNotEmpty) /// Filter empty string
      .toList();
  }

  /// Remove unstaged changes to all partially staged files, to avoid tasks from seeing them
  Future<void> hideUnstagedChanges() async {
    try {
      final files = processRenames(partiallyStagedFiles, false);
      await execGit(['checkout', '--force', '--', ...files], workingDirectory: gitDir);
    } catch (e) {
      handleError(e);
    }
  }

  void handleError(e) {
    throw e;
  }
}