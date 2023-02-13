String skippingBackup(bool hasInitialCommit, [List<String>? diff]) {
  final reason = diff == null
      ? '`--diff` was used'
      : hasInitialCommit
          ? '`--no-stash` was used'
          : 'there\'s no initial commit yet';
  return 'Skipping backup because $reason. \n';
}
