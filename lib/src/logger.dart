import 'dart:io' as io;

class Logger {
  final String name;
  final bool isDebug;
  Logger(this.name) : isDebug = io.Platform.environment['DEBUG'] == 'true';

  void stderr(String message) {
    io.stderr.writeln('$name $message');
  }

  void stdout(String message) {
    io.stdout.writeln('$name $message');
  }

  void debug(String message) {
    if (isDebug) {
      io.stdout.writeln('$name $message');
    }
  }
}
