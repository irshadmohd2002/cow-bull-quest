import 'package:cowbullgame/features/game/models/game_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameConfig.forWordLength', () {
    test('4-letter game allows 10 attempts', () {
      final config = GameConfig.forWordLength(4);
      expect(config.wordLength, 4);
      expect(config.maxAttempts, 10);
    });

    test('5-letter game allows 15 attempts', () {
      final config = GameConfig.forWordLength(5);
      expect(config.wordLength, 5);
      expect(config.maxAttempts, 15);
    });

    test('6-letter game allows 20 attempts', () {
      final config = GameConfig.forWordLength(6);
      expect(config.wordLength, 6);
      expect(config.maxAttempts, 20);
    });

    test('throws ArgumentError for a length shorter than supported', () {
      expect(() => GameConfig.forWordLength(3), throwsArgumentError);
    });

    test('throws ArgumentError for a length longer than supported', () {
      expect(() => GameConfig.forWordLength(7), throwsArgumentError);
    });

    test('throws ArgumentError for a zero or negative length', () {
      expect(() => GameConfig.forWordLength(0), throwsArgumentError);
      expect(() => GameConfig.forWordLength(-4), throwsArgumentError);
    });
  });

  group('GameConfig equality', () {
    test('instances built from the same word length are equal', () {
      expect(GameConfig.forWordLength(5), GameConfig.forWordLength(5));
    });

    test('instances built from different word lengths are not equal', () {
      expect(
        GameConfig.forWordLength(4) == GameConfig.forWordLength(5),
        isFalse,
      );
    });

    test('equal instances share a hashCode', () {
      expect(
        GameConfig.forWordLength(6).hashCode,
        GameConfig.forWordLength(6).hashCode,
      );
    });
  });
}
