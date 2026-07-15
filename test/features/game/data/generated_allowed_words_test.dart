import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the QZXJ guess-validation bug discovered during
/// release screenshot testing: `QZXJ` and `ABCD` were both accepted as
/// 4-letter Common guesses despite not being real words. Root-cause analysis
/// found the allowed-guess assets never contained either string — the bug
/// was that nothing in the validation pipeline ever consulted the
/// allowed-guess dictionary at all (see `GuessValidator`/`GameEngine`). This
/// test reads the real generated assets directly (not a fake) to keep that
/// root-cause finding pinned: if either string is ever accidentally added to
/// a generated word list, this fails independently of the validation-logic
/// fix.
void main() {
  group('generated allowed-guess word lists', () {
    for (final length in [4, 5, 6]) {
      test('allowed_words_$length.txt does not contain "qzxj" or "abcd"', () {
        final file = File('assets/generated/allowed_words_$length.txt');
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');

        final words = file
            .readAsStringSync()
            .split('\n')
            .where((line) => line.isNotEmpty)
            .toSet();

        expect(words, isNot(contains('qzxj')));
        expect(words, isNot(contains('abcd')));
      });
    }
  });
}
