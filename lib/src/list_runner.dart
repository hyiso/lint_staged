import 'dart:collection';
import 'dart:io';

import 'package:lint_staged/src/context.dart';
import 'package:lint_staged/src/symbols.dart';

import 'logger.dart';

///
/// `dart fix` for single file is supportted in Dart SDK 2.18
/// When running lower than 2.18, fix single file will failed.
///
/// Addint this to enable script to run on file parent.
///
/// eg. `dart fix --apply <file>/../` will resolve `<file>/../` to parent path of the file.
///
const _kFilePlaceholder = '<file>';

class ListRunner {
  List<String> matchedFiles;
  List<String> scripts;
  String? workingDirectory;
  LintStagedContext ctx;

  ListRunner({
    required this.matchedFiles,
    required this.scripts,
    required this.ctx,
    this.workingDirectory,
  });

  Future<void> run() async {
    await Future.wait(scripts.map((script) async {
      final args = script.split(' ');
      int index = args.length;
      for (var i = args.length - 1; i >= 0; i--) {
        if (args[i].contains(_kFilePlaceholder)) {
          index = i;
          break;
        }
      }
      var paths = matchedFiles;
      bool hasPlaceholderArg = index != args.length;
      if (hasPlaceholderArg) {
        paths = shrink(args[index], matchedFiles);
      }
      for (var path in paths) {
        final cmds = [...args];
        if (hasPlaceholderArg) {
          cmds[index] = path;
        } else {
          cmds.add(path);
        }
        logger.trace(cmds.join(' '));
        final result = await Process.run(cmds.removeAt(0), cmds,
            workingDirectory: workingDirectory);
        if (result.exitCode != 0) {
          ctx.errors.add(kTaskError);
        }
      }
    }));
  }
}

/// shrink files paths.
List<String> shrink(String placeholderArg, List<String> files) {
  /// resolve path string to parts
  List<String> resolve(String path) {
    final parts = path.split(Platform.pathSeparator);
    final stack = <String>[];
    for (var part in parts) {
      if (part == '.') {
        continue;
      }
      if (part == '..') {
        stack.removeLast();
        continue;
      }
      stack.add(part);
    }
    return stack;
  }

  /// traverse TreeNode
  List<String> traverse(TreeNode node) {
    if (node.children.isEmpty) {
      return [''];
    }
    final paths = <String>{};
    for (var entry in node.children.entries) {
      final dirs = [entry.key];
      final subs = traverse(entry.value);
      for (var sub in subs) {
        paths.add([...dirs, sub].join(Platform.pathSeparator));
      }
    }
    return paths.toList();
  }

  final root = TreeNode.root();
  for (var file in files) {
    final parts = resolve(placeholderArg.replaceFirst(_kFilePlaceholder, file));
    if (parts.isEmpty) continue;
    TreeNode parent = root;
    while (parts.isNotEmpty) {
      final dir = parts.removeAt(0);
      if (dir.isEmpty) {
        parent.children = Map.unmodifiable({});
        break;
      }
      if (parent.children is UnmodifiableMapBase ||
          parent.children is UnmodifiableMapView) break;
      if (parent.children[dir] == null) {
        parent.children[dir] = TreeNode(dir: dir, parent: parent);
      }
      parent = parent.children[dir]!;
    }
  }
  if (root.children.isEmpty) {
    return [];
  }
  return traverse(root);
}

class TreeNode {
  final String dir;
  TreeNode? parent;
  Map<String, TreeNode> children = {};

  TreeNode({required this.dir, this.parent})
      : assert(dir.isNotEmpty, 'dir must not be empty');

  TreeNode.root() : dir = '';
}
