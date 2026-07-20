import 'package:cowbullgame/models/daily_challenge_share_data.dart';
import 'package:cowbullgame/models/normal_win_share_data.dart';
import 'package:cowbullgame/models/streak_share_data.dart';
import 'package:cowbullgame/services/share_caption_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = ShareCaptionFormatter();

  group('ShareCaptionFormatter.normalWin', () {
    test('formats the exact required caption', () {
      final data = NormalWinShareData(
        difficultyLabel: 'Medium',
        attemptsUsed: 4,
        maxAttempts: 10,
        hintsUsed: 0,
        coinsEarned: 20,
      );
      expect(
        formatter.normalWin(data),
        'Cow Bull Quest\n'
        'Solved in 4/10 attempts.\n'
        'Can you solve it too?',
      );
    });

    test('never mentions the secret word, guesses, or coins', () {
      final data = NormalWinShareData(
        difficultyLabel: 'Hard',
        attemptsUsed: 6,
        maxAttempts: 10,
        hintsUsed: 1,
        coinsEarned: 25,
      );
      final caption = formatter.normalWin(data);
      expect(caption, isNot(contains('25')));
      expect(caption, isNot(contains('coin')));
    });
  });

  group('ShareCaptionFormatter.dailyChallengeWin', () {
    test('formats the exact required caption', () {
      final data = DailyChallengeShareData(
        dateLabel: '20 JULY 2026',
        attemptsUsed: 4,
        maxAttempts: 10,
        hintsUsed: 0,
        coinsEarned: 25,
        currentStreak: 5,
      );
      expect(
        formatter.dailyChallengeWin(data),
        'Cow Bull Quest Daily Challenge\n'
        'Solved in 4/10 attempts.\n'
        "Can you beat today's challenge?",
      );
    });
  });

  group('ShareCaptionFormatter.streak', () {
    test('formats the exact required caption for a plural streak', () {
      final data = StreakShareData(currentStreak: 7);
      expect(
        formatter.streak(data),
        'Cow Bull Quest\n'
        'I reached a 7-day streak.\n'
        "What's your biggest streak?",
      );
    });

    test('keeps "day" singular in the compound even for a 1-day streak', () {
      final data = StreakShareData(currentStreak: 1);
      expect(
        formatter.streak(data),
        'Cow Bull Quest\n'
        'I reached a 1-day streak.\n'
        "What's your biggest streak?",
      );
    });

    test('uses no em dash anywhere', () {
      final caption = formatter.streak(StreakShareData(currentStreak: 7));
      expect(caption, isNot(contains('—')));
    });
  });
}
