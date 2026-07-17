import 'package:cowbullgame/features/game/models/game_config.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameConfig.forSelection', () {
    test('4-letter game allows 10 attempts', () {
      final config = GameConfig.forSelection(
        wordLength: 4,
        difficulty: GameDifficulty.easy,
      );
      expect(config.wordLength, 4);
      expect(config.maxAttempts, 10);
    });

    test('5-letter game allows 15 attempts', () {
      final config = GameConfig.forSelection(
        wordLength: 5,
        difficulty: GameDifficulty.easy,
      );
      expect(config.wordLength, 5);
      expect(config.maxAttempts, 15);
    });

    test('6-letter game allows 20 attempts', () {
      final config = GameConfig.forSelection(
        wordLength: 6,
        difficulty: GameDifficulty.easy,
      );
      expect(config.wordLength, 6);
      expect(config.maxAttempts, 20);
    });

    test('throws ArgumentError for a length shorter than supported', () {
      expect(
        () => GameConfig.forSelection(
          wordLength: 3,
          difficulty: GameDifficulty.easy,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for a length longer than supported', () {
      expect(
        () => GameConfig.forSelection(
          wordLength: 7,
          difficulty: GameDifficulty.easy,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for a zero or negative length', () {
      expect(
        () => GameConfig.forSelection(
          wordLength: 0,
          difficulty: GameDifficulty.easy,
        ),
        throwsArgumentError,
      );
      expect(
        () => GameConfig.forSelection(
          wordLength: -4,
          difficulty: GameDifficulty.easy,
        ),
        throwsArgumentError,
      );
    });

    test('maxAttempts is the same for every difficulty at a given word '
        'length', () {
      for (final difficulty in GameDifficulty.values) {
        final config = GameConfig.forSelection(
          wordLength: 5,
          difficulty: difficulty,
        );
        expect(config.maxAttempts, 15);
      }
    });

    test('stores the requested difficulty', () {
      for (final difficulty in GameDifficulty.values) {
        final config = GameConfig.forSelection(
          wordLength: 4,
          difficulty: difficulty,
        );
        expect(config.difficulty, difficulty);
      }
    });
  });

  group('GameConfig.visibleWordLength', () {
    test('is 4 — the only word length the current UI can start', () {
      expect(GameConfig.visibleWordLength, 4);
    });

    test('every difficulty produces a 10-attempt config at the visible '
        'word length', () {
      for (final difficulty in GameDifficulty.values) {
        final config = GameConfig.forSelection(
          wordLength: GameConfig.visibleWordLength,
          difficulty: difficulty,
        );
        expect(config.wordLength, 4);
        expect(config.maxAttempts, 10);
      }
    });
  });

  group('GameConfig equality', () {
    test('instances built from the same word length and difficulty are '
        'equal', () {
      expect(
        GameConfig.forSelection(wordLength: 5, difficulty: GameDifficulty.easy),
        GameConfig.forSelection(wordLength: 5, difficulty: GameDifficulty.easy),
      );
    });

    test('instances built from different word lengths are not equal', () {
      expect(
        GameConfig.forSelection(
              wordLength: 4,
              difficulty: GameDifficulty.easy,
            ) ==
            GameConfig.forSelection(
              wordLength: 5,
              difficulty: GameDifficulty.easy,
            ),
        isFalse,
      );
    });

    test('instances built from different difficulties are not equal', () {
      expect(
        GameConfig.forSelection(
              wordLength: 5,
              difficulty: GameDifficulty.easy,
            ) ==
            GameConfig.forSelection(
              wordLength: 5,
              difficulty: GameDifficulty.hard,
            ),
        isFalse,
      );
    });

    test('equal instances share a hashCode', () {
      expect(
        GameConfig.forSelection(
          wordLength: 6,
          difficulty: GameDifficulty.common,
        ).hashCode,
        GameConfig.forSelection(
          wordLength: 6,
          difficulty: GameDifficulty.common,
        ).hashCode,
      );
    });

    test('instances with different difficulty have different hashCodes', () {
      // Not a strict equality requirement, but confirms difficulty
      // actually participates in the hash rather than being ignored.
      final easy = GameConfig.forSelection(
        wordLength: 6,
        difficulty: GameDifficulty.easy,
      );
      final hard = GameConfig.forSelection(
        wordLength: 6,
        difficulty: GameDifficulty.hard,
      );
      expect(easy.hashCode == hard.hashCode, isFalse);
    });
  });
}
