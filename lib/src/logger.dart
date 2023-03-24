import 'dart:io' as io;

import 'package:ansi/ansi.dart';

class Logger {
  final String name;
  Logger(this.name);

  void stderr(String message) {
    io.stderr.writeln(ansi.red('$name $message'));
  }

  void stdout(String message) {
    io.stdout.writeln('$name $message');
  }
}
