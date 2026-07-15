import 'package:cowbullgame/features/game/models/game_status.dart';
import 'package:cowbullgame/features/game/services/guess_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = GuessValidator();
  const defaultAllowedGuesses = {'crane'};

  GuessValidation validate(
    String rawGuess, {
    int secretWordLength = 5,
    Set<String> allowedGuesses = defaultAllowedGuesses,
  }) {
    return validator.validate(
      rawGuess: rawGuess,
      secretWordLength: secretWordLength,
      status: GameStatus.inProgress,
      allowedGuesses: allowedGuesses,
    );
  }

  group('GuessValidator', () {
    test('accepts a valid guess and normalizes it to lowercase', () {
      final result = validate('crane');
      expect(result, isA<ValidGuess>());
      expect((result as ValidGuess).normalizedGuess, 'crane');
    });

    test('rejects an empty guess as blank', () {
      final result = validate('');
      expect(result, isA<InvalidGuess>());
      expect((result as InvalidGuess).reason, GuessValidationFailure.blank);
    });

    test('rejects a whitespace-only guess as blank', () {
      final result = validate('     ');
      expect((result as InvalidGuess).reason, GuessValidationFailure.blank);
    });

    test('rejects a guess shorter than the secret word', () {
      final result = validate('cat');
      expect(
        (result as InvalidGuess).reason,
        GuessValidationFailure.incorrectLength,
      );
    });

    test('rejects a guess longer than the secret word', () {
      final result = validate('elephant');
      expect(
        (result as InvalidGuess).reason,
        GuessValidationFailure.incorrectLength,
      );
    });

    test('rejects a guess containing digits', () {
      final result = validate('cr4ne');
      expect(
        (result as InvalidGuess).reason,
        GuessValidationFailure.nonAlphabetic,
      );
    });

    test('rejects a guess containing punctuation', () {
      final result = validate("cr'ne");
      expect(
        (result as InvalidGuess).reason,
        GuessValidationFailure.nonAlphabetic,
      );
    });

    test('rejects a guess containing internal spaces', () {
      final result = validate('cr ne');
      expect(
        (result as InvalidGuess).reason,
        GuessValidationFailure.nonAlphabetic,
      );
    });

    test('accepts uppercase alphabetic input and lowercases it', () {
      final result = validate('CRANE');
      expect(result, isA<ValidGuess>());
      expect((result as ValidGuess).normalizedGuess, 'crane');
    });

    test('rejects any guess once the game has been won', () {
      final result = validator.validate(
        rawGuess: 'crane',
        secretWordLength: 5,
        status: GameStatus.won,
        allowedGuesses: defaultAllowedGuesses,
      );
      expect(
        (result as InvalidGuess).reason,
        GuessValidationFailure.gameAlreadyWon,
      );
    });

    test('rejects any guess once the game has been lost', () {
      final result = validator.validate(
        rawGuess: 'crane',
        secretWordLength: 5,
        status: GameStatus.lost,
        allowedGuesses: defaultAllowedGuesses,
      );
      expect(
        (result as InvalidGuess).reason,
        GuessValidationFailure.gameAlreadyLost,
      );
    });
  });

  group('GuessValidator dictionary check', () {
    test('rejects a well-formed guess absent from the allowed-guess dictionary '
        'as notInDictionary', () {
      final result = validate(
        'qzxj',
        secretWordLength: 4,
        allowedGuesses: const {'lace'},
      );
      expect(
        (result as InvalidGuess).reason,
        GuessValidationFailure.notInDictionary,
      );
    });

    test('rejects an alphabetic, correct-length guess not in the dictionary '
        'even though every individual letter is valid', () {
      final result = validate(
        'abcd',
        secretWordLength: 4,
        allowedGuesses: const {'lace'},
      );
      expect(
        (result as InvalidGuess).reason,
        GuessValidationFailure.notInDictionary,
      );
    });

    test('accepts a guess present in the allowed-guess dictionary', () {
      final result = validate(
        'lace',
        secretWordLength: 4,
        allowedGuesses: const {'lace', 'race'},
      );
      expect(result, isA<ValidGuess>());
      expect((result as ValidGuess).normalizedGuess, 'lace');
    });

    test('dictionary membership is checked case-insensitively against the '
        'normalized (lowercase) allowed set', () {
      final result = validate(
        'LACE',
        secretWordLength: 4,
        allowedGuesses: const {'lace'},
      );
      expect(result, isA<ValidGuess>());
      expect((result as ValidGuess).normalizedGuess, 'lace');
    });

    test(
      'an empty allowed-guess dictionary rejects every well-formed guess',
      () {
        final result = validate(
          'lace',
          secretWordLength: 4,
          allowedGuesses: const {},
        );
        expect(
          (result as InvalidGuess).reason,
          GuessValidationFailure.notInDictionary,
        );
      },
    );

    test('length and character-set failures take priority over dictionary '
        'membership, so those reasons are never masked', () {
      final tooShort = validate(
        'ab',
        secretWordLength: 4,
        allowedGuesses: const {},
      );
      expect(
        (tooShort as InvalidGuess).reason,
        GuessValidationFailure.incorrectLength,
      );

      final nonAlphabetic = validate(
        'ab3d',
        secretWordLength: 4,
        allowedGuesses: const {},
      );
      expect(
        (nonAlphabetic as InvalidGuess).reason,
        GuessValidationFailure.nonAlphabetic,
      );
    });
  });
}
