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
        help: 'Enable the backup stash, and revert in case of errors');
  final argResults = argParser.parse(arguments);
  final allowEmpty = argResults['allow-empty'] == true;
  final diff = argResults['diff'];
  final diffFilter = argResults['diff-filter'];
  final stash = argResults['stash'] == true;
  try {
    final passed = await lintStaged(
      allowEmpty: allowEmpty,
      diff: diff,
      diffFilter: diffFilter,
      stash: stash,
    );
    exit(passed ? 0 : 1);
  } catch (e, stack) {
    print(e);
    print(stack);
    exit(1);
  }
}
