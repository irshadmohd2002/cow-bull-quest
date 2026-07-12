import 'package:cowbullgame/features/game/models/game_status.dart';
import 'package:cowbullgame/features/game/services/guess_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = GuessValidator();

  GuessValidation validate(String rawGuess, {int secretWordLength = 5}) {
    return validator.validate(
      rawGuess: rawGuess,
      secretWordLength: secretWordLength,
      status: GameStatus.inProgress,
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
      );
      expect(
        (result as InvalidGuess).reason,
        GuessValidationFailure.gameAlreadyWon,
      );
    });
  });
}
