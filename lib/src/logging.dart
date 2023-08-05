import 'dart:async';
import 'dart:io' as io;

import 'package:ansi/ansi.dart';
import 'package:ansi_escapes/ansi_escapes.dart';
import 'package:verbose/verbose.dart';

class _Figures {
  static const success = '✔';
  static const error = '✗';
  static const skipped = '↓';
}

extension IOSink on io.IOSink {
  void failed(String message) {
    writeln('${ansi.red(_Figures.error)} $message');
  }

  void skipped(String message) {
    writeln('${ansi.grey(_Figures.skipped)} $message');
  }

  void warn(String message) {
    writeln(ansi.yellow(message));
  }

  void success(String message) {
    writeln('${ansi.green(_Figures.success)} $message');
  }
}

class Spinner {
  final Stopwatch _stopwatch;
  late Timer _timer;
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
    io.stdout.writeln('${ansi.red(_Figures.error)} $message');
  }

  void success(String message) {
    _stop();
    io.stdout.writeln('${ansi.green(_Figures.success)} $message');
  }

  void skipped(String message) {
    _stop();
    io.stdout.writeln('${ansi.grey(_Figures.skipped)} $message');
  }

  void _start() {
    io.stdout.write(_frame);
    _stopwatch.reset();
    _stopwatch.start();
    if (Verbose.enabled) {
      io.stdout.write('\n');
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      io.stdout.write('${ansiEscapes.eraseLines(_lineCount)}$_frame');
    });
  }

  void _stop() {
    io.stdout.write(ansiEscapes.eraseLines(_lineCount));
    _stopwatch.stop();
    if (Verbose.enabled) {
      return;
    } else if (_timer.isActive) {
      _timer.cancel();
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
