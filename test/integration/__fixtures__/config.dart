const kConfigFormatFix = '''lint_staged:
  .dart: dart format --fix
''';

const kConfigFormatExit = '''lint_staged:
  .dart: dart format --set-exit-if-changed
''';
