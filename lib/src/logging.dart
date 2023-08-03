import 'dart:async';
import 'dart:io' as io;

import 'package:ansi/ansi.dart';
import 'package:ansi_escapes/ansi_escapes.dart';
import 'package:verbose/verbose.dart';

class _Figures {
  static const success = '✔';
  static const error = '✖';
  static const skipped = '↓';
}

extension IOSink on io.IOSink {
  void failed(String message) {
    writeln(ansi.red('${_Figures.error} $message'));
  }

  void skipped(String message) {
    writeln('${ansi.grey(_Figures.skipped)} $message');
  }

  void success(String message) {
    writeln('${ansi.green(_Figures.success)} $message');
  }
}

class Spinner {
  final Stopwatch _stopwatch;
  late Timer _timer;
  late _SpinnerFrame _spinner;
  late int _lineCount;

  Spinner() : _stopwatch = Stopwatch() {
    _spinner = _SpinnerFrame();
  }

  Duration get elapsed => _stopwatch.elapsed;

  void progress(String message) {
    message = '${ansi.yellow(_spinner.take())} $message';
    _lineCount = message.split('\n').length;
    _start(message);
  }

  void failed(String message) {
    _stop('${ansi.red(_Figures.error)} $message');
  }

  void success(String message) {
    _stop('${ansi.green(_Figures.success)} $message');
  }

  void skipped(String message) {
    _stop('${ansi.grey(_Figures.skipped)} $message');
  }

  void _start(String message) {
    io.stdout.write(message);
    _stopwatch.reset();
    _stopwatch.start();
    if (Verbose.enabled) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      io.stdout.write('${ansiEscapes.eraseLines(_lineCount)}$message');
    });
  }

  void _stop(String message) {
    io.stdout.writeln('${ansiEscapes.eraseLines(_lineCount)}$message');
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

  String take() => _kFrames[_index++ % _kFrames.length];
}
