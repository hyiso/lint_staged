import 'dart:io';

import 'package:ansi_escapes/ansi_escapes.dart';
import 'package:ansi_slice/ansi_slice.dart';
import 'package:ansi_strip/ansi_strip.dart';
import 'package:ansi_wrap/ansi_wrap.dart';

int getWidth(IOSink stream) {
  return stdout.terminalColumns;
}

String fitToTerminalHeight(IOSink stream, String text) {
  final terminalHeight = stdout.terminalLines;
  final lines = text.split('\n');

  final toRemove = lines.length - terminalHeight;
  if (toRemove <= 0) {
    return text;
  }

  return sliceAnsi(
    text,
    start: stripAnsi(lines.sublist(0, toRemove).join('\n')).length + 1,
  );
}

Render createLogUpdate(IOSink stream, {bool showCursor = true}) {
  return Render(stream, showCursor);
}

final logUpdate = createLogUpdate(stdout);
final logUpdateStderr = createLogUpdate(stderr);

class Render {
  int previousLineCount = 0;
  int previousWidth;
  String previousOutput = '';
  final IOSink stream;
  final bool showCursor;

  Render(this.stream, this.showCursor) : previousWidth = getWidth(stream);

  void call(String output) {
    if (!showCursor) {
      stream.write(ansiEscapes.cursorHide);
    }
    output = fitToTerminalHeight(stream, output);
    final width = getWidth(stream);
    if (output == previousOutput && previousWidth == width) {
      return;
    }

    previousOutput = output;
    previousWidth = width;
    output = wrapAnsi(output, width, trim: false, hard: true, wordWrap: false);
    stream.write(ansiEscapes.eraseLines(previousLineCount) + output);
    previousLineCount = output.split('\n').length;
  }

  void clear() {
    stream.write(ansiEscapes.eraseLines(previousLineCount));
    previousOutput = '';
    previousWidth = getWidth(stream);
    previousLineCount = 0;
  }

  void done() {
    previousOutput = '';
    previousWidth = getWidth(stream);
    previousLineCount = 0;
    if (!showCursor) {
      stream.write(ansiEscapes.cursorShow);
    }
  }
}
