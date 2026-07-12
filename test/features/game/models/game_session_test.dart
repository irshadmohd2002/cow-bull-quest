import 'package:cowbullgame/features/game/models/game_session.dart';
import 'package:cowbullgame/features/game/models/game_status.dart';
import 'package:cowbullgame/features/game/models/guess.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameSession.start', () {
    test('normalizes the secret word to lowercase', () {
      final session = GameSession.start('CRANE');
      expect(session.secretWord, 'crane');
    });

    test('starts in-progress with no guess history', () {
      final session = GameSession.start('crane');
      expect(session.status, GameStatus.inProgress);
      expect(session.guesses, isEmpty);
    });

    test('throws ArgumentError for an empty secret word', () {
      expect(() => GameSession.start(''), throwsArgumentError);
    });

    test('throws ArgumentError for a secret word with non-letters', () {
      expect(() => GameSession.start('cr4ne'), throwsArgumentError);
    });
  });

  group('GameSession.copyWith', () {
    test('leaves the original instance unchanged', () {
      final original = GameSession.start('crane');
      final guess = Guess(
        word: 'grape',
        result: GuessResult(bulls: 1, cows: 1),
        turnNumber: 1,
      );

      final updated = original.copyWith(
        guesses: [guess],
        status: GameStatus.won,
      );

      expect(original.guesses, isEmpty);
      expect(original.status, GameStatus.inProgress);
      expect(updated.guesses, [guess]);
      expect(updated.status, GameStatus.won);
    });

    test('exposes guesses as an unmodifiable list', () {
      final session = GameSession.start('crane');
      expect(
        () => session.guesses.add(
          Guess(
            word: 'grape',
            result: GuessResult(bulls: 0, cows: 0),
            turnNumber: 1,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
