import 'dart:async';
import 'dart:io' as io;

import 'package:ansi/ansi.dart';
import 'package:ansi_escapes/ansi_escapes.dart';
import 'package:path/path.dart';
import 'package:verbose/verbose.dart';

class _Figures {
  static const success = '✔';
  static const error = '✗';
  static const skipped = '↓';
  static const warn = '⚠';
}

extension IOSink on io.IOSink {
  void failed(String message) {
    writeln('${red(_Figures.error)} $message');
  }

  void skipped(String message) {
    writeln('${grey(_Figures.skipped)} $message');
  }

  void warn(String message) {
    writeln(yellow('${_Figures.warn} $message'));
  }

  void error(String message) {
    writeln(red(message));
  }

  void success(String message) {
    writeln('${green(_Figures.success)} $message');
  }
}

final _isTest = basename(io.Platform.script.path).startsWith('test.dart');

class Spinner {
  final Stopwatch _stopwatch;
  Timer? _timer;
  _SpinnerFrame? _frame;
  late int _lineCount;

  Spinner() : _stopwatch = Stopwatch();

  Duration get elapsed => _stopwatch.elapsed;

  void progress(String message) {
    _lineCount = message.split('\n').length;
    _frame = _SpinnerFrame(message);
    _start();
  }

  void failed(String message) {
    _stop();
    io.stdout.writeln('${red(_Figures.error)} $message');
  }

  void success(String message) {
    _stop();
    io.stdout.writeln(
        '${green(_Figures.success)} ${message.padRight(40)}${elapsed.inMilliseconds}ms');
  }

  void skipped(String message) {
    _stop();
    io.stdout.writeln('${grey(_Figures.skipped)} $message');
  }

  void _start() {
    io.stdout.write(_frame);
    _stopwatch.reset();
    _stopwatch.start();
    if (Verbose.enabled || _isTest) {
      io.stdout.write('\n');
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      io.stdout.write('${ansiEscapes.eraseLines(_lineCount)}$_frame');
    });
  }

  void _stop() {
    if (Verbose.enabled || _isTest) {
      return;
    }
    if (_timer != null) {
      io.stdout.write(ansiEscapes.eraseLines(_lineCount));
      _stopwatch.stop();
      _timer?.cancel();
      _timer = null;
    }
  }
}

const _kFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

class _SpinnerFrame {
  int _index = 0;
  final String message;

  _SpinnerFrame(this.message);

  @override
  String toString() => '${_kFrames[_index++ % _kFrames.length]} $message';
}
