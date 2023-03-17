import 'package:lint_staged/src/lint_runner.dart';
import 'package:test/test.dart';

void main() {
  group('shrink', () {
    final placeholderArg = '<file>/../';

    test('top dir files', () {
      expect(
          shrink(placeholderArg, [
            'lib/a.dart',
            'lib/b.dart',
            'lib/c.dart',
          ]),
          equals(['lib/']));
    });

    test('sub dir files', () {
      expect(
          shrink(placeholderArg, [
            'lib/b/b.dart',
            'lib/c/c.dart',
          ]),
          equals(['lib/b/', 'lib/c/']));
    });

    test('mix dir files', () {
      expect(
          shrink(placeholderArg, [
            'lib/a.dart',
            'lib/b/b.dart',
            'lib/c/c/c.dart',
            'lib/d/c/d.dart',
          ]),
          equals(['lib/']));
    });
  });
}
