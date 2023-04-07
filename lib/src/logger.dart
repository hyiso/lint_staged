import 'dart:async';
import 'dart:io' as io;

import 'package:ansi/ansi.dart';
import 'package:lint_staged/src/figures.dart';

import 'log_update.dart';

const _kFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

class Logger {
  int _index = 0;
  Timer? _timer;
  Logger();

  void error(String message) {
    io.stderr.writeln(ansi.red('${Figures.error} $message'));
  }

  void progress(String message) {
    _index = 0;
    _timer?.cancel();
    logUpdate.clear();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      final frame = _kFrames[_index = ++_index % _kFrames.length];
      logUpdate('${ansi.yellow(frame)} $message\n');
    });
  }

  void success(String message) {
    logUpdate.clear();
    _timer?.cancel();
    io.stdout.writeln('${ansi.green(Figures.success)} $message');
  }
}
