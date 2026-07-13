import 'package:cowbullgame/features/statistics/models/completed_game.dart';
import 'package:cowbullgame/features/statistics/models/game_outcome.dart';
import 'package:cowbullgame/features/statistics/models/game_outcome_breakdown.dart';
import 'package:cowbullgame/features/statistics/models/statistics_snapshot.dart';
import 'package:cowbullgame/models/difficulty_selection.dart';
import 'package:flutter_test/flutter_test.dart';

CompletedGame _game(String id) => CompletedGame(
  id: id,
  completedAt: DateTime.utc(2026, 1, 1),
  wordLength: 5,
  difficulty: DifficultyOption.common,
  outcome: GameOutcome.won,
  attemptsUsed: 3,
  maxAttempts: 15,
);

void main() {
  group('StatisticsSnapshot.empty', () {
    test('has zeroed counters and no divide-by-zero errors', () {
      final snapshot = StatisticsSnapshot.empty();

      expect(snapshot.totalGames, 0);
      expect(snapshot.wins, 0);
      expect(snapshot.losses, 0);
      expect(snapshot.winRate, 0);
      expect(snapshot.currentWinStreak, 0);
      expect(snapshot.bestWinStreak, 0);
      expect(snapshot.averageAttemptsOnWins, isNull);
      expect(snapshot.byWordLength, isEmpty);
      expect(snapshot.byDifficulty, isEmpty);
      expect(snapshot.recentGames, isEmpty);
    });
  });

  group('StatisticsSnapshot derived values', () {
    test('totalGames is derived as wins + losses', () {
      final snapshot = StatisticsSnapshot(
        wins: 3,
        losses: 2,
        currentWinStreak: 0,
        bestWinStreak: 3,
        totalAttemptsOnWins: 9,
        byWordLength: const {},
        byDifficulty: const {},
        recentGames: const [],
      );
      expect(snapshot.totalGames, 5);
    });

    test('winRate divides wins by totalGames', () {
      final snapshot = StatisticsSnapshot(
        wins: 1,
        losses: 3,
        currentWinStreak: 0,
        bestWinStreak: 1,
        totalAttemptsOnWins: 5,
        byWordLength: const {},
        byDifficulty: const {},
        recentGames: const [],
      );
      expect(snapshot.winRate, 0.25);
    });

    test('averageAttemptsOnWins is null when there are no wins', () {
      final snapshot = StatisticsSnapshot(
        wins: 0,
        losses: 2,
        currentWinStreak: 0,
        bestWinStreak: 0,
        totalAttemptsOnWins: 0,
        byWordLength: const {},
        byDifficulty: const {},
        recentGames: const [],
      );
      expect(snapshot.averageAttemptsOnWins, isNull);
    });

    test('averageAttemptsOnWins divides the win-attempts total by wins', () {
      final snapshot = StatisticsSnapshot(
        wins: 2,
        losses: 0,
        currentWinStreak: 2,
        bestWinStreak: 2,
        totalAttemptsOnWins: 9,
        byWordLength: const {},
        byDifficulty: const {},
        recentGames: const [],
      );
      expect(snapshot.averageAttemptsOnWins, 4.5);
    });
  });

  group('StatisticsSnapshot validation', () {
    test('rejects a negative wins counter', () {
      expect(
        () => StatisticsSnapshot(
          wins: -1,
          losses: 0,
          currentWinStreak: 0,
          bestWinStreak: 0,
          totalAttemptsOnWins: 0,
          byWordLength: const {},
          byDifficulty: const {},
          recentGames: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects currentWinStreak greater than bestWinStreak', () {
      expect(
        () => StatisticsSnapshot(
          wins: 3,
          losses: 0,
          currentWinStreak: 3,
          bestWinStreak: 2,
          totalAttemptsOnWins: 9,
          byWordLength: const {},
          byDifficulty: const {},
          recentGames: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects more recentGames than maxRecentGames', () {
      expect(
        () => StatisticsSnapshot(
          wins: maxRecentGames + 1,
          losses: 0,
          currentWinStreak: 0,
          bestWinStreak: 0,
          totalAttemptsOnWins: 0,
          byWordLength: const {},
          byDifficulty: const {},
          recentGames: [
            for (var i = 0; i < maxRecentGames + 1; i++) _game('game-$i'),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('StatisticsSnapshot immutability', () {
    test('byWordLength is unmodifiable', () {
      final snapshot = StatisticsSnapshot.empty();
      expect(
        () => snapshot.byWordLength[4] = GameOutcomeBreakdown.empty,
        throwsUnsupportedError,
      );
    });

    test('recentGames is unmodifiable', () {
      final snapshot = StatisticsSnapshot.empty();
      expect(
        () => snapshot.recentGames.add(_game('x')),
        throwsUnsupportedError,
      );
    });
  });
}
