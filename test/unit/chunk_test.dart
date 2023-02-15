import 'package:lint_staged/src/chunk.dart';
import 'package:test/test.dart';

void main() {
  group('chunkFiles', () {
    const files = ['example.js', 'foo.js', 'bar.js', 'foo/bar.js'];

    test('should default to same value', () {
      final chunkedFiles = chunkFiles(['foo.js']);
      expect(
          chunkedFiles,
          equals([
            ['foo.js']
          ]));
    });

    test('should not chunk short argument string', () {
      final chunkedFiles = chunkFiles(files, maxArgLength: 1000);
      expect(chunkedFiles, equals([files]));
    });

    test('should chunk too long argument string', () {
      final chunkedFiles = chunkFiles(files, maxArgLength: 20);
      expect(
          chunkedFiles,
          equals([
            [files[0], files[1]],
            [files[2], files[3]],
          ]));
    });
  });
}
