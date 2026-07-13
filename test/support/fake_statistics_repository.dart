import 'dart:async';
import 'dart:math' as math;

import 'package:cowbullgame/features/statistics/data/statistics_repository.dart';
import 'package:cowbullgame/features/statistics/models/completed_game.dart';
import 'package:cowbullgame/features/statistics/models/game_outcome.dart';
import 'package:cowbullgame/features/statistics/models/statistics_snapshot.dart';

/// In-memory [StatisticsRepository] fake for controller/app-level tests.
///
/// [gate], if set, makes every operation await it before completing, so a
/// test can start an operation, start a second one that should supersede
/// it, then release the first and assert the stale result was discarded.
class FakeStatisticsRepository implements StatisticsRepository {
  FakeStatisticsRepository({StatisticsSnapshot? initialSnapshot})
    : _snapshot = initialSnapshot ?? StatisticsSnapshot.empty();

  StatisticsSnapshot _snapshot;

  bool failLoad = false;
  bool failRecord = false;
  bool failClear = false;

  Completer<void>? gate;

  int loadCallCount = 0;
  final List<CompletedGame> recordedGames = [];
  int clearCallCount = 0;

  Future<void> _awaitGate() async {
    final currentGate = gate;
    if (currentGate != null) await currentGate.future;
  }

  @override
  Future<StatisticsSnapshot> loadSnapshot() async {
    loadCallCount++;
    await _awaitGate();
    if (failLoad) {
      throw const StatisticsRepositoryException('forced load failure');
    }
    return _snapshot;
  }

  @override
  Future<StatisticsSnapshot> recordCompletedGame(CompletedGame game) async {
    recordedGames.add(game);
    await _awaitGate();
    if (failRecord) {
      throw const StatisticsRepositoryException('forced record failure');
    }
    if (_snapshot.recentGames.any((existing) => existing.id == game.id)) {
      return _snapshot;
    }
    final won = game.outcome == GameOutcome.won;
    final currentWinStreak = won ? _snapshot.currentWinStreak + 1 : 0;
    _snapshot = StatisticsSnapshot(
      wins: _snapshot.wins + (won ? 1 : 0),
      losses: _snapshot.losses + (won ? 0 : 1),
      currentWinStreak: currentWinStreak,
      bestWinStreak: math.max(_snapshot.bestWinStreak, currentWinStreak),
      totalAttemptsOnWins:
          _snapshot.totalAttemptsOnWins + (won ? game.attemptsUsed : 0),
      byWordLength: _snapshot.byWordLength,
      byDifficulty: _snapshot.byDifficulty,
      recentGames: [game, ..._snapshot.recentGames],
    );
    return _snapshot;
  }

  @override
  Future<StatisticsSnapshot> clearStatistics() async {
    clearCallCount++;
    await _awaitGate();
    if (failClear) {
      throw const StatisticsRepositoryException('forced clear failure');
    }
    _snapshot = StatisticsSnapshot.empty();
    return _snapshot;
  }
}
