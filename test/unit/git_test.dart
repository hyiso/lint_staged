import 'package:lint_staged/src/git.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('getDiffArg', () {
    final customDiff = ['origin/main..custom-branch'];
    final customDiffArr = ['origin/main', 'custom-branch'];
    final customDiffFilter = 'a';

    test('should default to sane value', () {
      final diff = getDiffArgs();
      expect(
          diff,
          equals(
              ['diff', '--name-only', '-z', '--diff-filter=ACMR', '--staged']));
    });

    test('should work only with diff set as string', () {
      final diff = getDiffArgs(diff: customDiff);
      expect(
          diff,
          equals([
            'diff',
            '--name-only',
            '-z',
            '--diff-filter=ACMR',
            'origin/main..custom-branch',
          ]));
    });

    test('should work only with diff set as comma separated list', () {
      final diff = getDiffArgs(diff: customDiffArr);
      expect(
          diff,
          equals([
            'diff',
            '--name-only',
            '-z',
            '--diff-filter=ACMR',
            'origin/main',
            'custom-branch',
          ]));
    });

    test('should work only with diffFilter set', () {
      final diff = getDiffArgs(diffFilter: customDiffFilter);
      expect(diff,
          equals(['diff', '--name-only', '-z', '--diff-filter=a', '--staged']));
    });

    test('should work with both diff and diffFilter set', () {
      final diff = getDiffArgs(diff: customDiff, diffFilter: customDiffFilter);
      expect(
          diff,
          equals([
            'diff',
            '--name-only',
            '-z',
            '--diff-filter=a',
            'origin/main..custom-branch',
          ]));
    });
  });

  group('parseGitZOutput', () {
    test('should split string from `git -z` control character', () {
      final input = 'a\u0000b\u0000c';
      expect(parseGitZOutput(input), equals(['a', 'b', 'c']));
    });

    test('should remove trailing `git -z` control character', () {
      final input = 'a\u0000';
      expect(parseGitZOutput(input), equals(['a']));
    });

    test('should handle empty input', () {
      final input = '';
      expect(parseGitZOutput(input), equals([]));
    });
  });
}
