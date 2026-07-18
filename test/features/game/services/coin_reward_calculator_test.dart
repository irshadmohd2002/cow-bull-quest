import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:cowbullgame/features/game/services/coin_reward_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = CoinRewardCalculator();

  group('CoinRewardBreakdown', () {
    test('none represents no reward at all', () {
      expect(CoinRewardBreakdown.none.totalCoinsEarned, 0);
      expect(CoinRewardBreakdown.none.rewarded, isFalse);
    });

    test('totalCoinsEarned sums every line', () {
      const breakdown = CoinRewardBreakdown(
        baseWinReward: 15,
        noHintBonus: 5,
        dailyChallengeBonus: 10,
      );
      expect(breakdown.totalCoinsEarned, 30);
    });

    test('rewarded is true whenever the total is positive', () {
      const breakdown = CoinRewardBreakdown(
        baseWinReward: 10,
        noHintBonus: 0,
        dailyChallengeBonus: 0,
      );
      expect(breakdown.rewarded, isTrue);
    });

    test('two breakdowns with identical lines are equal', () {
      const a = CoinRewardBreakdown(
        baseWinReward: 10,
        noHintBonus: 5,
        dailyChallengeBonus: 0,
      );
      const b = CoinRewardBreakdown(
        baseWinReward: 10,
        noHintBonus: 5,
        dailyChallengeBonus: 0,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('rewardForGame', () {
    test('a loss earns CoinRewardBreakdown.none regardless of difficulty or '
        'hints used', () {
      for (final difficulty in GameDifficulty.values) {
        expect(
          calculator.rewardForGame(
            won: false,
            difficulty: difficulty,
            hintsUsed: 0,
          ),
          CoinRewardBreakdown.none,
        );
        expect(
          calculator.rewardForGame(
            won: false,
            difficulty: difficulty,
            hintsUsed: 3,
          ),
          CoinRewardBreakdown.none,
        );
      }
    });

    test('an Easy win with hints used earns a 10-coin base reward, no '
        'no-hint bonus, and no Daily Challenge bonus', () {
      final breakdown = calculator.rewardForGame(
        won: true,
        difficulty: GameDifficulty.easy,
        hintsUsed: 1,
      );
      expect(breakdown.baseWinReward, 10);
      expect(breakdown.noHintBonus, 0);
      expect(breakdown.dailyChallengeBonus, 0);
      expect(breakdown.totalCoinsEarned, 10);
    });

    test('a Medium (common) win with hints used earns a 15-coin base '
        'reward', () {
      final breakdown = calculator.rewardForGame(
        won: true,
        difficulty: GameDifficulty.common,
        hintsUsed: 1,
      );
      expect(breakdown.baseWinReward, 15);
      expect(breakdown.totalCoinsEarned, 15);
    });

    test('a Hard win with hints used earns a 20-coin base reward', () {
      final breakdown = calculator.rewardForGame(
        won: true,
        difficulty: GameDifficulty.hard,
        hintsUsed: 2,
      );
      expect(breakdown.baseWinReward, 20);
      expect(breakdown.totalCoinsEarned, 20);
    });

    test('a no-hint win adds a 5-coin no-hint bonus on top of the '
        'difficulty base', () {
      expect(
        calculator
            .rewardForGame(
              won: true,
              difficulty: GameDifficulty.easy,
              hintsUsed: 0,
            )
            .totalCoinsEarned,
        15,
      );
      expect(
        calculator
            .rewardForGame(
              won: true,
              difficulty: GameDifficulty.common,
              hintsUsed: 0,
            )
            .totalCoinsEarned,
        20,
      );
      expect(
        calculator
            .rewardForGame(
              won: true,
              difficulty: GameDifficulty.hard,
              hintsUsed: 0,
            )
            .totalCoinsEarned,
        25,
      );
      expect(
        calculator
            .rewardForGame(
              won: true,
              difficulty: GameDifficulty.easy,
              hintsUsed: 0,
            )
            .noHintBonus,
        5,
      );
    });

    test('never sets dailyChallengeBonus for an ordinary game', () {
      final breakdown = calculator.rewardForGame(
        won: true,
        difficulty: GameDifficulty.hard,
        hintsUsed: 0,
      );
      expect(breakdown.dailyChallengeBonus, 0);
    });
  });

  group('rewardForDailyChallenge', () {
    test('a loss earns CoinRewardBreakdown.none even when official', () {
      expect(
        calculator.rewardForDailyChallenge(
          won: false,
          isOfficial: true,
          hintsUsed: 0,
        ),
        CoinRewardBreakdown.none,
      );
    });

    test('a non-official win (a replay) earns CoinRewardBreakdown.none '
        'entirely, not just missing the official bonus', () {
      expect(
        calculator.rewardForDailyChallenge(
          won: true,
          isOfficial: false,
          hintsUsed: 0,
        ),
        CoinRewardBreakdown.none,
      );
      expect(
        calculator.rewardForDailyChallenge(
          won: true,
          isOfficial: false,
          hintsUsed: 3,
        ),
        CoinRewardBreakdown.none,
      );
    });

    test('an official win with hints used earns the Medium base plus the '
        'official bonus (15 + 10 = 25), with no no-hint bonus', () {
      final breakdown = calculator.rewardForDailyChallenge(
        won: true,
        isOfficial: true,
        hintsUsed: 1,
      );
      expect(breakdown.baseWinReward, 15);
      expect(breakdown.noHintBonus, 0);
      expect(breakdown.dailyChallengeBonus, 10);
      expect(breakdown.totalCoinsEarned, 25);
    });

    test('an official, no-hint win earns the Medium base plus the no-hint '
        'bonus plus the official bonus (15 + 5 + 10 = 30)', () {
      final breakdown = calculator.rewardForDailyChallenge(
        won: true,
        isOfficial: true,
        hintsUsed: 0,
      );
      expect(breakdown.baseWinReward, 15);
      expect(breakdown.noHintBonus, 5);
      expect(breakdown.dailyChallengeBonus, 10);
      expect(breakdown.totalCoinsEarned, 30);
    });
  });
}
