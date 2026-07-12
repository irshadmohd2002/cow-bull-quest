import 'package:cowbullgame/features/game/models/game_session.dart';
import 'package:cowbullgame/features/game/models/game_status.dart';
import 'package:cowbullgame/features/game/models/guess.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameSession.start', () {
    test('normalizes the secret word to lowercase', () {
      final session = GameSession.start('CRANE', maxAttempts: 15);
      expect(session.secretWord, 'crane');
    });

    test('starts in-progress with no guess history', () {
      final session = GameSession.start('crane', maxAttempts: 15);
      expect(session.status, GameStatus.inProgress);
      expect(session.guesses, isEmpty);
    });

    test('throws ArgumentError for an empty secret word', () {
      expect(() => GameSession.start('', maxAttempts: 15), throwsArgumentError);
    });

    test('throws ArgumentError for a secret word with non-letters', () {
      expect(
        () => GameSession.start('cr4ne', maxAttempts: 15),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for a non-positive maxAttempts', () {
      expect(
        () => GameSession.start('crane', maxAttempts: 0),
        throwsArgumentError,
      );
      expect(
        () => GameSession.start('crane', maxAttempts: -1),
        throwsArgumentError,
      );
    });
  });

  group('GameSession attempt state', () {
    test('a fresh session has used no attempts and has all remaining', () {
      final session = GameSession.start('crane', maxAttempts: 15);
      expect(session.maxAttempts, 15);
      expect(session.attemptsUsed, 0);
      expect(session.attemptsRemaining, 15);
    });

    test('attemptsUsed derives from guess history length', () {
      final session = GameSession.start('crane', maxAttempts: 15).copyWith(
        guesses: [
          Guess(
            word: 'grape',
            result: GuessResult(bulls: 1, cows: 1),
            turnNumber: 1,
          ),
          Guess(
            word: 'stone',
            result: GuessResult(bulls: 0, cows: 2),
            turnNumber: 2,
          ),
        ],
      );
      expect(session.attemptsUsed, 2);
      expect(session.attemptsRemaining, 13);
    });

    test('attemptsRemaining never becomes negative', () {
      final guesses = List.generate(
        20,
        (i) => Guess(
          word: 'grape',
          result: GuessResult(bulls: 0, cows: 0),
          turnNumber: i + 1,
        ),
      );
      final session = GameSession.start(
        'crane',
        maxAttempts: 15,
      ).copyWith(guesses: guesses);
      expect(session.attemptsUsed, 20);
      expect(session.attemptsRemaining, 0);
    });

    test('maxAttempts is preserved across copyWith', () {
      final session = GameSession.start(
        'crane',
        maxAttempts: 10,
      ).copyWith(status: GameStatus.won);
      expect(session.maxAttempts, 10);
    });
  });

  group('GameSession.copyWith', () {
    test('leaves the original instance unchanged', () {
      final original = GameSession.start('crane', maxAttempts: 15);
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
      final session = GameSession.start('crane', maxAttempts: 15);
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
