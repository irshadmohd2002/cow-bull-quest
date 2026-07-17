import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:cowbullgame/features/game/models/game_session.dart';
import 'package:cowbullgame/features/game/models/game_status.dart';
import 'package:cowbullgame/features/game/models/guess.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:cowbullgame/features/game/services/game_result_share_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = GameResultShareFormatter();

  GameSession wonSession({List<Guess>? guesses}) =>
      GameSession.start('lace', maxAttempts: 10).copyWith(
        status: GameStatus.won,
        guesses:
            guesses ??
            [
              Guess(
                word: 'race',
                result: GuessResult(bulls: 2, cows: 1),
                turnNumber: 1,
              ),
              Guess(
                word: 'trace',
                result: GuessResult(bulls: 3, cows: 0),
                turnNumber: 2,
              ),
              Guess(
                word: 'lace',
                result: GuessResult(bulls: 4, cows: 0),
                turnNumber: 3,
              ),
            ],
      );

  GameSession lostSession({List<Guess>? guesses}) {
    final history =
        guesses ??
        List.generate(
          10,
          (i) => Guess(
            word: 'mock',
            result: GuessResult(bulls: 0, cows: 2),
            turnNumber: i + 1,
          ),
        );
    return GameSession.start(
      'lace',
      maxAttempts: 10,
    ).copyWith(status: GameStatus.lost, guesses: history);
  }

  group('win result', () {
    test('contains the app name', () {
      final text = formatter.format(
        session: wonSession(),
        difficulty: GameDifficulty.common,
        hintsUsed: 0,
      );
      expect(text, contains('Cow Bull Quest'));
    });

    test('shows Medium instead of Common for GameDifficulty.common', () {
      final text = formatter.format(
        session: wonSession(),
        difficulty: GameDifficulty.common,
        hintsUsed: 0,
      );
      expect(text, contains('Medium'));
      expect(text, isNot(contains('Common')));
      expect(text, isNot(contains('common')));
    });

    test('shows Easy and Hard labels for the other difficulties', () {
      expect(
        formatter.format(
          session: wonSession(),
          difficulty: GameDifficulty.easy,
          hintsUsed: 0,
        ),
        contains('Easy'),
      );
      expect(
        formatter.format(
          session: wonSession(),
          difficulty: GameDifficulty.hard,
          hintsUsed: 0,
        ),
        contains('Hard'),
      );
    });

    test('contains attempts used out of the max', () {
      final text = formatter.format(
        session: wonSession(),
        difficulty: GameDifficulty.easy,
        hintsUsed: 0,
      );
      expect(text, contains('Solved in 3/10 attempts'));
    });

    test('omits the hints line when zero hints were used', () {
      final text = formatter.format(
        session: wonSession(),
        difficulty: GameDifficulty.easy,
        hintsUsed: 0,
      );
      expect(text, isNot(contains('hint')));
    });

    test('includes a singular hint line for exactly one hint', () {
      final text = formatter.format(
        session: wonSession(),
        difficulty: GameDifficulty.easy,
        hintsUsed: 1,
      );
      expect(text, contains('1 hint used'));
      expect(text, isNot(contains('1 hints used')));
    });

    test('includes a plural hint line for more than one hint', () {
      final text = formatter.format(
        session: wonSession(),
        difficulty: GameDifficulty.easy,
        hintsUsed: 2,
      );
      expect(text, contains('2 hints used'));
    });

    test('bulls/cows in each guess line match the stored GuessResult', () {
      final text = formatter.format(
        session: wonSession(),
        difficulty: GameDifficulty.easy,
        hintsUsed: 0,
      );
      expect(text, contains('Guess 1: 🟩 2 Bulls · 🟨 1 Cow'));
      expect(text, contains('Guess 2: 🟩 3 Bulls · 🟨 0 Cows'));
      expect(text, contains('Guess 3: 🟩 4 Bulls · 🟨 0 Cows'));
    });

    test('uses singular Bull/Cow for a count of exactly one', () {
      final text = formatter.format(
        session: wonSession(
          guesses: [
            Guess(
              word: 'race',
              result: GuessResult(bulls: 1, cows: 1),
              turnNumber: 1,
            ),
          ],
        ),
        difficulty: GameDifficulty.easy,
        hintsUsed: 0,
      );
      expect(text, contains('🟩 1 Bull ·'));
      expect(text, contains('🟨 1 Cow'));
      expect(text, isNot(contains('1 Bulls')));
      expect(text, isNot(contains('1 Cows')));
    });

    test('includes an optional call to action', () {
      final text = formatter.format(
        session: wonSession(),
        difficulty: GameDifficulty.easy,
        hintsUsed: 0,
      );
      expect(text, contains('Can you solve it?'));
    });

    test('never contains the secret word', () {
      final text = formatter.format(
        session: wonSession(),
        difficulty: GameDifficulty.easy,
        hintsUsed: 0,
      );
      expect(text.toLowerCase(), isNot(contains('lace')));
    });

    test('never contains any submitted guess letters', () {
      final text = formatter.format(
        session: wonSession(),
        difficulty: GameDifficulty.easy,
        hintsUsed: 0,
      );
      expect(text.toLowerCase(), isNot(contains('race')));
      expect(text.toLowerCase(), isNot(contains('trace')));
    });
  });

  group('loss result', () {
    test('states the game was not solved, without a call to action', () {
      final text = formatter.format(
        session: lostSession(),
        difficulty: GameDifficulty.hard,
        hintsUsed: 0,
      );
      expect(text, contains('Not solved in 10 attempts'));
      expect(text, isNot(contains('Can you solve it?')));
      expect(text, isNot(contains('Solved in')));
    });

    test('includes the hints line only when hints were used', () {
      final withoutHints = formatter.format(
        session: lostSession(),
        difficulty: GameDifficulty.hard,
        hintsUsed: 0,
      );
      final withHints = formatter.format(
        session: lostSession(),
        difficulty: GameDifficulty.hard,
        hintsUsed: 3,
      );
      expect(withoutHints, isNot(contains('hint')));
      expect(withHints, contains('3 hints used'));
    });

    test('never contains the secret word', () {
      final text = formatter.format(
        session: lostSession(),
        difficulty: GameDifficulty.hard,
        hintsUsed: 0,
      );
      expect(text.toLowerCase(), isNot(contains('lace')));
    });

    test('never contains any submitted guess letters', () {
      final text = formatter.format(
        session: lostSession(),
        difficulty: GameDifficulty.hard,
        hintsUsed: 0,
      );
      expect(text.toLowerCase(), isNot(contains('mock')));
    });
  });

  group('unusual histories', () {
    test('an empty guess history still produces valid, non-empty text', () {
      final session = GameSession.start(
        'lace',
        maxAttempts: 10,
      ).copyWith(status: GameStatus.lost, guesses: const []);

      final text = formatter.format(
        session: session,
        difficulty: GameDifficulty.easy,
        hintsUsed: 0,
      );

      expect(text, isNotEmpty);
      expect(text, contains('Cow Bull Quest'));
      expect(text, contains('Not solved in 10 attempts'));
    });

    test('a single-guess win still produces valid text', () {
      final session = GameSession.start('lace', maxAttempts: 10).copyWith(
        status: GameStatus.won,
        guesses: [
          Guess(
            word: 'lace',
            result: GuessResult(bulls: 4, cows: 0),
            turnNumber: 1,
          ),
        ],
      );

      final text = formatter.format(
        session: session,
        difficulty: GameDifficulty.easy,
        hintsUsed: 0,
      );

      expect(text, contains('Solved in 1/10 attempts'));
      expect(text, contains('Guess 1: 🟩 4 Bulls · 🟨 0 Cows'));
    });
  });

  group('determinism', () {
    test('formatting the same session twice yields identical text', () {
      final session = wonSession();
      final first = formatter.format(
        session: session,
        difficulty: GameDifficulty.common,
        hintsUsed: 1,
      );
      final second = formatter.format(
        session: session,
        difficulty: GameDifficulty.common,
        hintsUsed: 1,
      );
      expect(first, second);
    });
  });
}
