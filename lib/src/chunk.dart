import 'dart:math';

///
/// Chunk files into sub-lists based on the length of the resulting argument string
///
List<List<String>> chunkFiles(
  List<String> files, {
  int maxArgLength = 0,
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
  int position = 0;
  for (var i = 0; i < chunkCount; i++) {
    final chunkLength = ((list.length - position) / (chunkCount - i)).ceil();
    chunked.add([]);
    chunked[i] = list.sublist(position, chunkLength + position);
    position += chunkLength;
  }
  return chunked;
}
