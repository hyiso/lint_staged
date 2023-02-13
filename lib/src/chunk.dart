import 'dart:io';
import 'dart:math';

///
/// Chunk files into sub-lists based on the length of the resulting argument string
///
List<List<String>> chunkFiles({
  required List<String> files,
}) {
  if (maxArgLength <= 0) {
    return [files];
  }
  final fileListLength = files.join(' ').length;
  final chunkCount = min((fileListLength / maxArgLength).ceil(), files.length);
  return chunkList(files, chunkCount);
}

/// Chunk list into sub-lists
List<List<T>> chunkList<T>(List<T> list, int chunkCount) {
  if (chunkCount == 1) return [list];
  final chunked = <List<T>>[];
  var position = 0;
  for (var i = 0; i < chunkCount; i++) {
    final chunkLength = ((list.length - position) / chunkCount - i).ceil();
    chunked.add([]);
    chunked[i] = list.sublist(position, chunkLength + position);
    position += chunkLength;
  }
  return chunked;
}

///
/// Get the maximum length of a command-line argument string based on current platform
///
/// https://serverfault.com/questions/69430/what-is-the-maximum-length-of-a-command-line-in-mac-os-x
/// https://support.microsoft.com/en-us/help/830473/command-prompt-cmd-exe-command-line-string-limitation
/// https://unix.stackexchange.com/a/120652
///
int get maxArgLength {
  if (Platform.isMacOS) {
    return 262144;
  }
  return 131072;
}
