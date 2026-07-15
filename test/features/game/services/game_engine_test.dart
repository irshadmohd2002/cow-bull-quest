import 'package:cowbullgame/features/game/models/game_config.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:cowbullgame/features/game/models/game_status.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:cowbullgame/features/game/services/game_engine.dart';
import 'package:cowbullgame/features/game/services/guess_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = GameEngine();
  final config5 = GameConfig.forSelection(
    wordLength: 5,
    difficulty: GameDifficulty.easy,
  );
  final config4 = GameConfig.forSelection(
    wordLength: 4,
    difficulty: GameDifficulty.easy,
  );

  // The allowed-guess dictionaries these tests submit against. Every
  // well-formed guess literal used below (by length) must appear here, or
  // it will be rejected as notInDictionary rather than scored.
  const allowed5 = {'crane', 'canoe', 'aaaaa', 'bbbbb', 'grape'};
  const allowed4 = {'lace', 'race', 'mace', 'pace'};

  group('GameEngine.startGame', () {
    test('starts with empty history and in-progress status', () {
      final session = engine.startGame(secretWord: 'crane', config: config5);
      expect(session.guesses, isEmpty);
      expect(session.status, GameStatus.inProgress);
      expect(session.secretWord, 'crane');
    });

    test('takes its attempt limit from the config', () {
      final session = engine.startGame(secretWord: 'crane', config: config5);
      expect(session.maxAttempts, 15);
      expect(session.attemptsUsed, 0);
      expect(session.attemptsRemaining, 15);
    });

    test(
      'throws ArgumentError when secretWord length does not match config',
      () {
        expect(
          () => engine.startGame(secretWord: 'crane', config: config4),
          throwsArgumentError,
        );
      },
    );
  });

  group('GameEngine.submitGuess', () {
    test('accepts and normalizes a valid guess', () {
      final session = engine.startGame(secretWord: 'crane', config: config5);
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'CRANE',
        allowedGuesses: allowed5,
      );
      expect(submission, isA<GuessAccepted>());
      final accepted = submission as GuessAccepted;
      expect(accepted.guess.word, 'crane');
    });

    test('records the correct scored result', () {
      final session = engine.startGame(secretWord: 'crane', config: config5);
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'canoe',
        allowedGuesses: allowed5,
      );
      final accepted = submission as GuessAccepted;
      // secret: crane (c,r,a,n,e), guess: canoe (c,a,n,o,e)
      // index0: c==c bull; index4: e==e bull.
      // remaining secret: r,a,n; remaining guess: a,n,o -> both a and n
      // find a match -> 2 cows.
      expect(accepted.guess.result, GuessResult(bulls: 2, cows: 2));
    });

    test('preserves earlier history when a new guess is added', () {
      var session = engine.startGame(secretWord: 'crane', config: config5);
      session =
          (engine.submitGuess(
                    session: session,
                    rawGuess: 'aaaaa',
                    allowedGuesses: allowed5,
                  )
                  as GuessAccepted)
              .session;
      final firstGuess = session.guesses.single;

      session =
          (engine.submitGuess(
                    session: session,
                    rawGuess: 'bbbbb',
                    allowedGuesses: allowed5,
                  )
                  as GuessAccepted)
              .session;

      expect(session.guesses, hasLength(2));
      expect(session.guesses.first, firstGuess);
      expect(session.guesses.first.turnNumber, 1);
      expect(session.guesses.last.turnNumber, 2);
    });

    test('invalid guesses do not change history', () {
      final session = engine.startGame(secretWord: 'crane', config: config5);
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'cr4ne',
        allowedGuesses: allowed5,
      );
      expect(submission, isA<GuessRejected>());
      expect(
        (submission as GuessRejected).reason,
        GuessValidationFailure.nonAlphabetic,
      );
      expect(session.guesses, isEmpty);
    });

    test('a winning guess changes the status to won', () {
      final session = engine.startGame(secretWord: 'crane', config: config5);
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'crane',
        allowedGuesses: allowed5,
      );
      final accepted = submission as GuessAccepted;
      expect(accepted.session.status, GameStatus.won);
    });

    test('the winning guess itself is recorded in history', () {
      final session = engine.startGame(secretWord: 'crane', config: config5);
      final accepted =
          engine.submitGuess(
                session: session,
                rawGuess: 'crane',
                allowedGuesses: allowed5,
              )
              as GuessAccepted;
      expect(accepted.session.guesses, hasLength(1));
      expect(
        accepted.session.guesses.single.result,
        GuessResult(bulls: 5, cows: 0),
      );
    });

    test('guesses submitted after winning are rejected', () {
      final session = engine.startGame(secretWord: 'crane', config: config5);
      final wonSession =
          (engine.submitGuess(
                    session: session,
                    rawGuess: 'crane',
                    allowedGuesses: allowed5,
                  )
                  as GuessAccepted)
              .session;

      final submission = engine.submitGuess(
        session: wonSession,
        rawGuess: 'grape',
        allowedGuesses: allowed5,
      );

      expect(submission, isA<GuessRejected>());
      expect(
        (submission as GuessRejected).reason,
        GuessValidationFailure.gameAlreadyWon,
      );
      expect(wonSession.guesses, hasLength(1));
    });

    test('does not mutate the previous session on a valid guess', () {
      final originalSession = engine.startGame(
        secretWord: 'crane',
        config: config5,
      );
      final submission = engine.submitGuess(
        session: originalSession,
        rawGuess: 'grape',
        allowedGuesses: allowed5,
      );
      final newSession = (submission as GuessAccepted).session;

      expect(originalSession.guesses, isEmpty);
      expect(originalSession.status, GameStatus.inProgress);
      expect(newSession.guesses, hasLength(1));
      expect(!identical(originalSession, newSession), isTrue);
    });

    test('does not mutate the previous session on an invalid guess', () {
      final originalSession = engine.startGame(
        secretWord: 'crane',
        config: config5,
      );
      engine.submitGuess(
        session: originalSession,
        rawGuess: '123',
        allowedGuesses: allowed5,
      );

      expect(originalSession.guesses, isEmpty);
      expect(originalSession.status, GameStatus.inProgress);
    });

    test(
      'a rejected submission carries the exact original session instance',
      () {
        final originalSession = engine.startGame(
          secretWord: 'crane',
          config: config5,
        );
        final submission = engine.submitGuess(
          session: originalSession,
          rawGuess: 'cr4ne',
          allowedGuesses: allowed5,
        );
        expect(submission, isA<GuessRejected>());
        expect(identical(submission.session, originalSession), isTrue);
      },
    );

    test('an accepted submission exposes the new session via .session', () {
      final originalSession = engine.startGame(
        secretWord: 'crane',
        config: config5,
      );
      final submission = engine.submitGuess(
        session: originalSession,
        rawGuess: 'grape',
        allowedGuesses: allowed5,
      );
      expect(submission, isA<GuessAccepted>());
      expect(identical(submission.session, originalSession), isFalse);
    });
  });

  group('GameEngine dictionary validation', () {
    test('rejects a well-formed guess absent from the allowed-guess dictionary '
        'as notInDictionary, without hard-coding any specific word', () {
      final session = engine.startGame(secretWord: 'lace', config: config4);
      // 'qzxj' is alphabetic and exactly 4 letters, so it clears every
      // format check and is rejected purely for dictionary absence.
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'qzxj',
        allowedGuesses: allowed4,
      );
      expect(submission, isA<GuessRejected>());
      expect(
        (submission as GuessRejected).reason,
        GuessValidationFailure.notInDictionary,
      );
    });

    test('a dictionary-rejected guess consumes no attempt', () {
      final session = engine.startGame(secretWord: 'lace', config: config4);
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'qzxj',
        allowedGuesses: allowed4,
      );
      final rejected = submission as GuessRejected;
      expect(rejected.session.attemptsUsed, 0);
      expect(rejected.session.attemptsRemaining, 10);
    });

    test('a dictionary-rejected guess is never added to history', () {
      final session = engine.startGame(secretWord: 'lace', config: config4);
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'qzxj',
        allowedGuesses: allowed4,
      );
      expect(submission.session.guesses, isEmpty);
    });

    test('a well-formed guess made of otherwise-valid letters is still '
        'rejected when it is not itself in the dictionary', () {
      final session = engine.startGame(secretWord: 'lace', config: config4);
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'abcd',
        allowedGuesses: allowed4,
      );
      expect(submission, isA<GuessRejected>());
      expect(
        (submission as GuessRejected).reason,
        GuessValidationFailure.notInDictionary,
      );
    });

    test('a guess present in the allowed dictionary is accepted and '
        'consumes an attempt', () {
      final session = engine.startGame(secretWord: 'lace', config: config4);
      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'race',
        allowedGuesses: allowed4,
      );
      expect(submission, isA<GuessAccepted>());
      expect(submission.session.attemptsUsed, 1);
    });
  });

  group('GameEngine attempt-limit rules', () {
    test('a valid incorrect guess consumes exactly one attempt', () {
      final session = engine.startGame(secretWord: 'lace', config: config4);
      final accepted =
          engine.submitGuess(
                session: session,
                rawGuess: 'race',
                allowedGuesses: allowed4,
              )
              as GuessAccepted;
      expect(accepted.session.attemptsUsed, 1);
      expect(accepted.session.attemptsRemaining, 9);
    });

    test('an invalid guess consumes no attempt', () {
      final session = engine.startGame(secretWord: 'lace', config: config4);
      final rejected =
          engine.submitGuess(
                session: session,
                rawGuess: 'toolong',
                allowedGuesses: allowed4,
              )
              as GuessRejected;
      expect(rejected.session.attemptsUsed, 0);
      expect(rejected.session.attemptsRemaining, 10);
    });

    test('multiple accepted guesses reduce remaining attempts correctly', () {
      var session = engine.startGame(secretWord: 'lace', config: config4);
      for (final guess in ['race', 'mace', 'pace']) {
        session =
            (engine.submitGuess(
                      session: session,
                      rawGuess: guess,
                      allowedGuesses: allowed4,
                    )
                    as GuessAccepted)
                .session;
      }
      expect(session.attemptsUsed, 3);
      expect(session.attemptsRemaining, 7);
      expect(session.status, GameStatus.inProgress);
    });

    test('a correct guess before the final attempt wins', () {
      var session = engine.startGame(secretWord: 'lace', config: config4);
      session =
          (engine.submitGuess(
                    session: session,
                    rawGuess: 'race',
                    allowedGuesses: allowed4,
                  )
                  as GuessAccepted)
              .session;
      session =
          (engine.submitGuess(
                    session: session,
                    rawGuess: 'lace',
                    allowedGuesses: allowed4,
                  )
                  as GuessAccepted)
              .session;
      expect(session.status, GameStatus.won);
      expect(session.attemptsUsed, 2);
    });

    test('a correct guess on the final attempt wins, not loses', () {
      var session = engine.startGame(secretWord: 'lace', config: config4);
      // Exhaust 9 of 10 attempts with wrong guesses.
      for (var i = 0; i < 9; i++) {
        session =
            (engine.submitGuess(
                      session: session,
                      rawGuess: 'race',
                      allowedGuesses: allowed4,
                    )
                    as GuessAccepted)
                .session;
      }
      expect(session.attemptsRemaining, 1);

      final finalSubmission =
          engine.submitGuess(
                session: session,
                rawGuess: 'lace',
                allowedGuesses: allowed4,
              )
              as GuessAccepted;
      expect(finalSubmission.session.status, GameStatus.won);
      expect(finalSubmission.session.attemptsUsed, 10);
      expect(finalSubmission.session.attemptsRemaining, 0);
    });

    test('a valid incorrect final guess loses', () {
      var session = engine.startGame(secretWord: 'lace', config: config4);
      for (var i = 0; i < 9; i++) {
        session =
            (engine.submitGuess(
                      session: session,
                      rawGuess: 'race',
                      allowedGuesses: allowed4,
                    )
                    as GuessAccepted)
                .session;
      }
      expect(session.attemptsRemaining, 1);

      final finalSubmission =
          engine.submitGuess(
                session: session,
                rawGuess: 'mace',
                allowedGuesses: allowed4,
              )
              as GuessAccepted;
      expect(finalSubmission.session.status, GameStatus.lost);
      expect(finalSubmission.session.attemptsUsed, 10);
      expect(finalSubmission.session.attemptsRemaining, 0);
    });

    test('no submission is accepted once the game has been lost', () {
      var session = engine.startGame(secretWord: 'lace', config: config4);
      for (var i = 0; i < 10; i++) {
        session =
            (engine.submitGuess(
                      session: session,
                      rawGuess: 'race',
                      allowedGuesses: allowed4,
                    )
                    as GuessAccepted)
                .session;
      }
      expect(session.status, GameStatus.lost);

      final submission = engine.submitGuess(
        session: session,
        rawGuess: 'lace',
        allowedGuesses: allowed4,
      );
      expect(submission, isA<GuessRejected>());
      expect(
        (submission as GuessRejected).reason,
        GuessValidationFailure.gameAlreadyLost,
      );
      expect(identical(submission.session, session), isTrue);
      // The losing guess itself remains the final entry in history.
      expect(session.guesses, hasLength(10));
    });
  });
}
