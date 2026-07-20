import 'package:cowbullgame/models/daily_challenge_share_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyChallengeShareData', () {
    test('attemptsLabel and hintsLabel format like NormalWinShareData', () {
      final data = DailyChallengeShareData(
        dateLabel: '20 JULY 2026',
        attemptsUsed: 4,
        maxAttempts: 10,
        hintsUsed: 2,
        coinsEarned: 25,
        currentStreak: 3,
      );
      expect(data.attemptsLabel, 'Solved in 4/10 attempts');
      expect(data.hintsLabel, '2 hints used');
    });

    test('hintsLabel is "No hints used" for zero hints', () {
      final data = DailyChallengeShareData(
        dateLabel: '1 JANUARY 2026',
        attemptsUsed: 1,
        maxAttempts: 10,
        hintsUsed: 0,
        coinsEarned: 25,
        currentStreak: 1,
      );
      expect(data.hintsLabel, 'No hints used');
    });

    test('throws if attemptsUsed exceeds maxAttempts', () {
      expect(
        () => DailyChallengeShareData(
          dateLabel: '1 JANUARY 2026',
          attemptsUsed: 11,
          maxAttempts: 10,
          hintsUsed: 0,
          coinsEarned: 25,
          currentStreak: 1,
        ),
        throwsArgumentError,
      );
    });

    test('throws for a negative currentStreak', () {
      expect(
        () => DailyChallengeShareData(
          dateLabel: '1 JANUARY 2026',
          attemptsUsed: 1,
          maxAttempts: 10,
          hintsUsed: 0,
          coinsEarned: 25,
          currentStreak: -1,
        ),
        throwsArgumentError,
      );
    });

    test('equality is value-based', () {
      DailyChallengeShareData build() => DailyChallengeShareData(
        dateLabel: '20 JULY 2026',
        attemptsUsed: 4,
        maxAttempts: 10,
        hintsUsed: 0,
        coinsEarned: 25,
        currentStreak: 6,
      );
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });
  });
}
