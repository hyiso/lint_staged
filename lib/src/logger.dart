import 'dart:async';
import 'dart:io' as io;

import 'package:ansi/ansi.dart';
import 'package:ansi_escapes/ansi_escapes.dart';
import 'package:verbose/verbose.dart';

import 'figures.dart';
import 'spinner.dart';

class Logger {
  SpinnerProgress? _progress;

  Logger();

  void error(String message) {
    _cancelProgress();
    io.stderr.writeln(ansi.red('${Figures.error} $message'));
  }

  SpinnerProgress progress(String message) {
    _cancelProgress();
    return _progress = SpinnerProgress(message);
  }

  void _cancelProgress() {
    _progress?.cancel();
    _progress = null;
  }

  void success(String message) {
    _cancelProgress();
    io.stdout.writeln('${ansi.green(Figures.success)} $message');
  }
}

class SpinnerProgress {
  final String message;
  final Stopwatch _stopwatch;
  final bool showTiming;
  late final Timer _timer;
  late final Spinner _spinner;
  late final int _lineCount;

  SpinnerProgress(this.message, {this.showTiming = false})
      : _stopwatch = Stopwatch()..start() {
    _spinner = Spinner();
    _lineCount = Verbose.enabled ? 0 : message.split('\n').length;
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      _updateDisplay();
    });
    io.stdout.write('${ansi.yellow(_spinner.toString())} $message');
    _updateDisplay();
  }

  Duration get elapsed => _stopwatch.elapsed;

  void cancel() {
    if (_timer.isActive) {
      _timer.cancel();
      _updateDisplay(cancelled: true);
    }
  }

  void finish() {
    if (_timer.isActive) {
      _timer.cancel();
      _updateDisplay(finished: true);
    }
  }

  void _updateDisplay({bool finished = false, bool cancelled = false}) {
    var char = ansi.yellow(_spinner.toString());
    if (finished) {
      char = ansi.green(Figures.success);
    } else if (cancelled) {
      char = ' ';
    }
    io.stdout.write(
        '${ansiEscapes.eraseLines(_lineCount)}$char ${message.padRight(40)}');
    if (showTiming) {
      final time = (elapsed.inMilliseconds / 1000.0).toStringAsFixed(1);
      io.stdout.write('${time}s');
    }
    if (finished || cancelled || Verbose.enabled) {
      io.stdout.writeln();
    }
  }
}
