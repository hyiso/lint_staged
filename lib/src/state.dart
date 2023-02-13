class LintState {
  bool hasPartiallyStagedFiles = false;
  bool shouldBackup = false;
  Set<Object> errors = {};
  List<String> output = [];
}

LintState getInitialState() => LintState();
