import 'package:cowbullgame/features/game/models/game_status.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:cowbullgame/features/game/services/game_engine.dart';
import 'package:cowbullgame/features/game/services/guess_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = GameEngine();

  group('GameEngine.startGame', () {
    test('starts with empty history and in-progress status', () {
      final session = engine.startGame(secretWord: 'crane');
      expect(session.guesses, isEmpty);
      expect(session.status, GameStatus.inProgress);
      expect(session.secretWord, 'crane');
    });
  });

  group('GameEngine.submitGuess', () {
    test('accepts and normalizes a valid guess', () {
      final session = engine.startGame(secretWord: 'crane');
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'CRANE',
      );
      expect(submission, isA<GuessAccepted>());
      final accepted = submission as GuessAccepted;
      expect(accepted.guess.word, 'crane');
    });

    test('records the correct scored result', () {
      final session = engine.startGame(secretWord: 'crane');
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'canoe',
      );
      final accepted = submission as GuessAccepted;
      // secret: crane (c,r,a,n,e), guess: canoe (c,a,n,o,e)
      // index0: c==c bull; index4: e==e bull.
      // remaining secret: r,a,n; remaining guess: a,n,o -> both a and n
      // find a match -> 2 cows.
      expect(accepted.guess.result, GuessResult(bulls: 2, cows: 2));
    });

    test('preserves earlier history when a new guess is added', () {
      var session = engine.startGame(secretWord: 'crane');
      session =
          (engine.submitGuess(session: session, rawGuess: 'aaaaa')
                  as GuessAccepted)
              .session;
      final firstGuess = session.guesses.single;

      session =
          (engine.submitGuess(session: session, rawGuess: 'bbbbb')
                  as GuessAccepted)
              .session;

      expect(session.guesses, hasLength(2));
      expect(session.guesses.first, firstGuess);
      expect(session.guesses.first.turnNumber, 1);
      expect(session.guesses.last.turnNumber, 2);
    });

    test('invalid guesses do not change history', () {
      final session = engine.startGame(secretWord: 'crane');
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'cr4ne',
      );
      expect(submission, isA<GuessRejected>());
      expect(
        (submission as GuessRejected).reason,
        GuessValidationFailure.nonAlphabetic,
      );
      expect(session.guesses, isEmpty);
    });

    test('a winning guess changes the status to won', () {
      final session = engine.startGame(secretWord: 'crane');
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'crane',
      );
      final accepted = submission as GuessAccepted;
      expect(accepted.session.status, GameStatus.won);
    });

    test('the winning guess itself is recorded in history', () {
      final session = engine.startGame(secretWord: 'crane');
      final accepted =
          engine.submitGuess(session: session, rawGuess: 'crane')
              as GuessAccepted;
      expect(accepted.session.guesses, hasLength(1));
      expect(
        accepted.session.guesses.single.result,
        GuessResult(bulls: 5, cows: 0),
      );
    });

    test('guesses submitted after winning are rejected', () {
      final session = engine.startGame(secretWord: 'crane');
      final wonSession =
          (engine.submitGuess(session: session, rawGuess: 'crane')
                  as GuessAccepted)
              .session;

      final submission = engine.submitGuess(
        session: wonSession,
        rawGuess: 'grape',
      );

      expect(submission, isA<GuessRejected>());
      expect(
        (submission as GuessRejected).reason,
        GuessValidationFailure.gameAlreadyWon,
      );
      expect(wonSession.guesses, hasLength(1));
    });

    test('does not mutate the previous session on a valid guess', () {
      final originalSession = engine.startGame(secretWord: 'crane');
      final submission = engine.submitGuess(
        session: originalSession,
        rawGuess: 'grape',
      );
      final newSession = (submission as GuessAccepted).session;

      expect(originalSession.guesses, isEmpty);
      expect(originalSession.status, GameStatus.inProgress);
      expect(newSession.guesses, hasLength(1));
      expect(!identical(originalSession, newSession), isTrue);
    });

    test('does not mutate the previous session on an invalid guess', () {
      final originalSession = engine.startGame(secretWord: 'crane');
      engine.submitGuess(session: originalSession, rawGuess: '123');

      expect(originalSession.guesses, isEmpty);
      expect(originalSession.status, GameStatus.inProgress);
    });
  });
}
