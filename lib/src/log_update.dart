import 'dart:io';

import 'package:ansi_escapes/ansi_escapes.dart';
import 'package:ansi_slice/ansi_slice.dart';
import 'package:ansi_strip/ansi_strip.dart';
import 'package:ansi_wrap/ansi_wrap.dart';

int getWidth(Stdout sink) {
  if (sink.hasTerminal) {
    return sink.terminalColumns;
  }
  return 80;
}

int getHeight(Stdout sink) {
  if (sink.hasTerminal) {
    return sink.terminalLines;
  }
  return 24;
}

String fitToTerminalHeight(Stdout sink, String text) {
  final terminalHeight = getHeight(sink);
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

Render createLogUpdate(Stdout stream, {bool showCursor = true}) {
  return Render(stream, showCursor);
}

final logUpdate = createLogUpdate(stdout);
final logUpdateStderr = createLogUpdate(stderr);

class Render {
  int previousLineCount = 0;
  int previousWidth;
  String previousOutput = '';
  final Stdout sink;
  final bool showCursor;

  Render(this.sink, this.showCursor) : previousWidth = getWidth(sink);

  void call(String output) {
    if (!showCursor) {
      sink.write(ansiEscapes.cursorHide);
    }
    output = fitToTerminalHeight(sink, output);
    final width = getWidth(sink);
    if (output == previousOutput && previousWidth == width) {
      return;
    }

    previousOutput = output;
    previousWidth = width;
    output = wrapAnsi(output, width, trim: false, hard: true, wordWrap: false);
    sink.write(ansiEscapes.eraseLines(previousLineCount) + output);
    previousLineCount = output.split('\n').length;
  }

  void clear() {
    sink.write(ansiEscapes.eraseLines(previousLineCount));
    previousOutput = '';
    previousWidth = getWidth(sink);
    previousLineCount = 0;
  }

  void done() {
    previousOutput = '';
    previousWidth = getWidth(sink);
    previousLineCount = 0;
    if (!showCursor) {
      sink.write(ansiEscapes.cursorShow);
    }
  }
}
