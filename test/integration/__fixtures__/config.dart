const kConfigFormatFix = '''lint_staged:
  'lib/**.dart': dart format --fix
''';

const kConfigFormatExit = '''lint_staged:
  'lib/**.dart': dart format --set-exit-if-changed
''';
