import 'package:cowbullgame/features/game/models/guess.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Guess', () {
    test('instances with the same fields are equal', () {
      final result = GuessResult(bulls: 1, cows: 1);
      expect(
        Guess(word: 'crane', result: result, turnNumber: 1),
        Guess(word: 'crane', result: result, turnNumber: 1),
      );
    });

    test('instances with different turn numbers are not equal', () {
      final result = GuessResult(bulls: 1, cows: 1);
      expect(
        Guess(word: 'crane', result: result, turnNumber: 1) ==
            Guess(word: 'crane', result: result, turnNumber: 2),
        isFalse,
      );
    });

    test('throws ArgumentError for a turn number below 1', () {
      final result = GuessResult(bulls: 0, cows: 0);
      expect(
        () => Guess(word: 'crane', result: result, turnNumber: 0),
        throwsArgumentError,
      );
    });
  });
}
