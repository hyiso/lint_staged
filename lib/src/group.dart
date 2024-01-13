import 'package:glob/glob.dart';
import 'package:verbose/verbose.dart';

final _verbose = Verbose('lint_staged:group');

class Group {
  final List<String> scripts;
  final List<String> files;

  Group({required this.scripts, required this.files});
}

Map<String, Group> groupFilesByConfig(
    {required Map<String, List<String>> config, required List<String> files}) {
  final fileSet = files.toSet();
  final groups = <String, Group>{};

  // Separate config into inclusion and exclusion patterns
  final includeConfig = config.entries.where((e) => !e.key.startsWith('!'));
  final excludeConfig = config.entries.where((e) => e.key.startsWith('!'));

  // First, include files based on inclusion patterns
  for (var entry in includeConfig) {
    final glob = Glob(entry.key);
    final matchedFiles = fileSet.where((file) => glob.matches(file)).toList();

    if (matchedFiles.isNotEmpty) {
      _verbose('$glob matched files: $matchedFiles');
      groups[entry.key] = Group(scripts: entry.value, files: matchedFiles);
    }
  }

  // Next, exclude files based on exclusion patterns
  for (var entry in excludeConfig) {
    final glob = Glob(entry.key.substring(1)); // Remove the '!' prefix
    final excludedFiles = fileSet.where((file) => glob.matches(file)).toSet();

    // Remove excluded files from each group
    for (var group in groups.values) {
      group.files.removeWhere((file) => excludedFiles.contains(file));
    }
  }

  return groups;
}
