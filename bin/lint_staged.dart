import 'dart:io';

import 'package:args/args.dart';
import 'package:lint_staged/lint_staged.dart';

void main(List<String> arguments) async {
  final argParser = ArgParser()
    ..addMultiOption('diff',
        help:
            'Override the default "--staged" flag of "git diff" to get list of files. Implies "--no-stash".')
    ..addOption('diff-filter',
        help:
            'Override the default "--diff-filter=ACMR" flag of "git diff" to get list of files')
    ..addFlag('allow-empty',
        help: 'Allow empty commits when tasks revert all staged changes')
    ..addFlag('stash',
        defaultsTo: true,
        negatable: true,
        help: 'Enable the backup stash, and revert in case of errors')
    ..addOption('processes',
        defaultsTo: null,
        abbr: 'p',
        help:
            'The maximum processes can run at the same time, limits it can reduce the memory usage');
  final argResults = argParser.parse(arguments);
  final allowEmpty = argResults['allow-empty'] == true;
  final diff = argResults['diff'];
  final diffFilter = argResults['diff-filter'];
  final stash = argResults['stash'] == true;
  final numberOfProcessors = argResults['processes'] != null
      ? int.parse(argResults['processes'])
      : null;
  final passed = await lintStaged(
      allowEmpty: allowEmpty,
      diff: diff,
      diffFilter: diffFilter,
      stash: stash,
      maxArgLength: _maxArgLength ~/ 2,
      numOfProcesses: numberOfProcessors);
  exit(passed ? 0 : 1);
}

///
/// Get the maximum length of a command-line argument string based on current platform
///
/// https://serverfault.com/questions/69430/what-is-the-maximum-length-of-a-command-line-in-mac-os-x
/// https://support.microsoft.com/en-us/help/830473/command-prompt-cmd-exe-command-line-string-limitation
/// https://unix.stackexchange.com/a/120652
///
int get _maxArgLength {
  if (Platform.isMacOS) {
    return 262144;
  }
  return 131072;
}
