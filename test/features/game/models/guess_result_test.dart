import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuessResult', () {
    test('instances with the same bulls and cows are equal', () {
      expect(GuessResult(bulls: 2, cows: 1), GuessResult(bulls: 2, cows: 1));
    });

    test('instances with different bulls or cows are not equal', () {
      expect(
        GuessResult(bulls: 2, cows: 1) == GuessResult(bulls: 1, cows: 2),
        isFalse,
      );
    });

    test('equal instances share a hashCode', () {
      expect(
        GuessResult(bulls: 3, cows: 0).hashCode,
        GuessResult(bulls: 3, cows: 0).hashCode,
      );
    });

    test('throws ArgumentError for a negative bulls count', () {
      expect(() => GuessResult(bulls: -1, cows: 0), throwsArgumentError);
    });

    test('throws ArgumentError for a negative cows count', () {
      expect(() => GuessResult(bulls: 0, cows: -1), throwsArgumentError);
    });
  });
}
