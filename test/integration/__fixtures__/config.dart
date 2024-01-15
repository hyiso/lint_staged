const kConfigFormatFix = '''lint_staged:
  'lib/**.dart': dart format --fix
''';

const kConfigFormatFixWithIgnore = '''lint_staged:
  'lib/**.dart': dart format --fix
  '!lib/*.g.dart': dart format --fix
''';

const kConfigFormatExit = '''lint_staged:
  'lib/**.dart': dart format --set-exit-if-changed
''';
