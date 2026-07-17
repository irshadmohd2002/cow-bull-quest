import 'package:cowbullgame/features/game/models/guess.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:cowbullgame/features/game/models/revealed_hint.dart';
import 'package:cowbullgame/features/game/services/hint_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = HintService();

  Guess guessOf(String word, {int turnNumber = 1}) => Guess(
    word: word,
    result: GuessResult(bulls: 0, cows: 0),
    turnNumber: turnNumber,
  );

  group('HintService.computeHint with no history', () {
    test('reveals the lowest-index position (position 0)', () {
      final result = service.computeHint(
        secretWord: 'lace',
        guesses: const [],
        previousHints: const [],
      );

      expect(result, isA<HintComputed>());
      expect(
        (result as HintComputed).hint,
        const RevealedHint(position: 0, letter: 'l'),
      );
    });

    test('is deterministic — repeated calls with identical inputs return '
        'identical results', () {
      final first = service.computeHint(
        secretWord: 'lace',
        guesses: const [],
        previousHints: const [],
      );
      final second = service.computeHint(
        secretWord: 'lace',
        guesses: const [],
        previousHints: const [],
      );

      expect((first as HintComputed).hint, (second as HintComputed).hint);
    });
  });

  group('HintService.computeHint never reveals a known Bull position', () {
    test('skips a position matched by an accepted guess', () {
      // 'lxxx' matches secret at position 0 only — that Bull position must
      // never be re-revealed as a hint.
      final result = service.computeHint(
        secretWord: 'lace',
        guesses: [guessOf('lxxx')],
        previousHints: const [],
      );

      expect(
        (result as HintComputed).hint,
        const RevealedHint(position: 1, letter: 'a'),
      );
    });

    test('skips every position matched across multiple guesses', () {
      // 'lxxx' matches position 0; 'xxce' matches positions 2 and 3.
      final result = service.computeHint(
        secretWord: 'lace',
        guesses: [guessOf('lxxx'), guessOf('xxce', turnNumber: 2)],
        previousHints: const [],
      );

      expect(
        (result as HintComputed).hint,
        const RevealedHint(position: 1, letter: 'a'),
      );
    });

    test('a fully correct guess (a win) means no useful hint remains', () {
      final result = service.computeHint(
        secretWord: 'lace',
        guesses: [guessOf('lace')],
        previousHints: const [],
      );

      expect(result, isA<NoHintAvailable>());
    });
  });

  group(
    'HintService.computeHint never repeats a previously hinted position',
    () {
      test('skips a position already revealed by an earlier hint', () {
        final result = service.computeHint(
          secretWord: 'lace',
          guesses: const [],
          previousHints: const [RevealedHint(position: 0, letter: 'l')],
        );

        expect(
          (result as HintComputed).hint,
          const RevealedHint(position: 1, letter: 'a'),
        );
      });

      test('skips every previously hinted position, in combination with '
          'known Bulls', () {
        final result = service.computeHint(
          secretWord: 'lace',
          guesses: [guessOf('xxce')], // Bulls at positions 2, 3
          previousHints: const [RevealedHint(position: 0, letter: 'l')],
        );

        expect(
          (result as HintComputed).hint,
          const RevealedHint(position: 1, letter: 'a'),
        );
      });
    },
  );

  group('HintService.computeHint when no useful hint remains', () {
    test('returns NoHintAvailable once every position is known from hints '
        'alone', () {
      final result = service.computeHint(
        secretWord: 'lace',
        guesses: const [],
        previousHints: const [
          RevealedHint(position: 0, letter: 'l'),
          RevealedHint(position: 1, letter: 'a'),
          RevealedHint(position: 2, letter: 'c'),
          RevealedHint(position: 3, letter: 'e'),
        ],
      );

      expect(result, isA<NoHintAvailable>());
    });

    test('returns NoHintAvailable once every position is known from a mix '
        'of Bulls and hints', () {
      final result = service.computeHint(
        secretWord: 'lace',
        guesses: [guessOf('laxx')], // Bulls at positions 0, 1
        previousHints: const [
          RevealedHint(position: 2, letter: 'c'),
          RevealedHint(position: 3, letter: 'e'),
        ],
      );

      expect(result, isA<NoHintAvailable>());
    });

    test('the only remaining position is still validly revealed — the '
        'entire answer is never exposed by one hint', () {
      final result = service.computeHint(
        secretWord: 'lace',
        guesses: const [],
        previousHints: const [
          RevealedHint(position: 0, letter: 'l'),
          RevealedHint(position: 1, letter: 'a'),
          RevealedHint(position: 2, letter: 'c'),
        ],
      );

      expect(
        (result as HintComputed).hint,
        const RevealedHint(position: 3, letter: 'e'),
      );
    });
  });

  group('HintService.computeHint letter correctness', () {
    test('the revealed letter always matches the secret word at the stated '
        'position', () {
      const secretWord = 'gold';
      final result = service.computeHint(
        secretWord: secretWord,
        guesses: const [],
        previousHints: const [],
      );
      final hint = (result as HintComputed).hint;

      expect(secretWord[hint.position], hint.letter);
    });
  });
}
