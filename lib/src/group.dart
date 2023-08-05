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
  for (var entry in config.entries) {
    final glob = Glob(entry.key);
    final files = <String>[];
    for (var file in fileSet) {
      if (glob.matches(file)) {
        files.add(file);
      }
    }

    /// Files should only match a single entry
    for (var file in files) {
      fileSet.remove(file);
    }
    if (files.isNotEmpty) {
      _verbose('$glob matched files: $files');
      groups[entry.key] = Group(scripts: entry.value, files: files);
    }
  }
  return groups;
}
