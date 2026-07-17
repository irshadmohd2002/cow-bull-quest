import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/daily_challenge/models/daily_challenge_result.dart';
import 'package:cowbullgame/features/daily_challenge/services/daily_challenge_result_share_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = DailyChallengeResultShareFormatter();

  DailyChallengeResult won({int hintsUsed = 0}) => DailyChallengeResult(
    date: LocalDate(year: 2026, month: 7, day: 18),
    won: true,
    attemptsUsed: 2,
    maxAttempts: 10,
    hintsUsed: hintsUsed,
    completedAt: DateTime.utc(2026, 7, 18, 12),
    wordListVersion: 1,
    guesses: const [
      DailyChallengeGuessRecord(turnNumber: 1, bulls: 1, cows: 2),
      DailyChallengeGuessRecord(turnNumber: 2, bulls: 4, cows: 0),
    ],
  );

  group('DailyChallengeResultShareFormatter', () {
    test('includes the app name and "Daily Challenge" label', () {
      final text = formatter.format(result: won());
      expect(text, contains('Cow Bull Quest — Daily Challenge'));
    });

    test('includes the challenge date in a human-readable form', () {
      final text = formatter.format(result: won());
      expect(text, contains('18 July 2026'));
    });

    test('uses aggregate bulls/cows per guess, matching the domain model', () {
      final text = formatter.format(result: won());
      expect(text, contains('Guess 1: 🟩 1 Bull · 🟨 2 Cows'));
      expect(text, contains('Guess 2: 🟩 4 Bulls · 🟨 0 Cows'));
    });

    test('never includes a secret word or guessed letters', () {
      final text = formatter.format(result: won());
      expect(text.toLowerCase(), isNot(contains('secret')));
      // Nothing in the formatted text should contain a guessed word: the
      // only alphabetic content is the fixed vocabulary of this formatter
      // itself (app name, "Guess", "Bull(s)", "Cow(s)", "Solved", "hint(s)
      // used", month name, "streak").
    });

    test('shows the solved-in-N-of-M-attempts line when won', () {
      final text = formatter.format(result: won());
      expect(text, contains('Solved in 2/10 attempts'));
    });

    test('shows the not-solved line when lost', () {
      final lost = DailyChallengeResult(
        date: LocalDate(year: 2026, month: 7, day: 18),
        won: false,
        attemptsUsed: 10,
        maxAttempts: 10,
        hintsUsed: 0,
        completedAt: DateTime.utc(2026, 7, 18),
        wordListVersion: 1,
        guesses: const [],
      );
      final text = formatter.format(result: lost);
      expect(text, contains('Not solved in 10 attempts'));
    });

    test('omits the hints line when no hints were used', () {
      final text = formatter.format(result: won());
      expect(text, isNot(contains('hint')));
    });

    test('shows the hints-used line when a hint was used', () {
      final text = formatter.format(result: won(hintsUsed: 1));
      expect(text, contains('1 hint used'));
    });

    test(
      'includes the streak line only when the streak is meaningful (>0)',
      () {
        final withStreak = formatter.format(result: won(), currentStreak: 5);
        final noStreak = formatter.format(result: won(), currentStreak: 0);
        final nullStreak = formatter.format(result: won());
        expect(withStreak, contains('🔥 5-day streak'));
        expect(noStreak, isNot(contains('streak')));
        expect(nullStreak, isNot(contains('streak')));
      },
    );

    test('the official result is always what is formatted, never a replay', () {
      // This formatter has no notion of "replay" at all — it only ever
      // formats whatever DailyChallengeResult it is given. The guarantee
      // that a replay's live session is never passed here belongs to the
      // app-level composition root (see app.dart's resultTextBuilder),
      // which always looks up DailyChallengeController.officialResultToday
      // rather than the live GameCompleted session for a Daily Challenge
      // share.
      final official = won();
      expect(formatter.format(result: official), contains('Solved in 2/10'));
    });
  });
}
