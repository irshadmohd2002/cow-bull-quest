import 'dart:async';
import 'dart:convert';

import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:cowbullgame/features/statistics/data/local_statistics_repository.dart';
import 'package:cowbullgame/features/statistics/data/statistics_repository.dart';
import 'package:cowbullgame/features/statistics/models/completed_game.dart';
import 'package:cowbullgame/features/statistics/models/game_outcome.dart';
import 'package:cowbullgame/features/statistics/models/statistics_snapshot.dart';
import 'package:cowbullgame/models/difficulty_selection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_preferences_store.dart';

CompletedGame _game({
  required String id,
  DateTime? completedAt,
  int wordLength = 5,
  DifficultyOption difficulty = DifficultyOption.common,
  GameOutcome outcome = GameOutcome.won,
  int attemptsUsed = 3,
  int maxAttempts = 15,
}) => CompletedGame(
  id: id,
  completedAt: completedAt ?? DateTime.utc(2026, 1, 1),
  wordLength: wordLength,
  difficulty: difficulty,
  outcome: outcome,
  attemptsUsed: attemptsUsed,
  maxAttempts: maxAttempts,
);

/// A self-consistent version-2 document: [byWordLength]/[byDifficulty] sum
/// to [wins]/[losses], every `recentGames` id is present in
/// [recordedGameIds], and there are no internal duplicates — i.e. a
/// document every corruption test starts from before breaking exactly one
/// invariant.
Map<String, Object?> _validDocumentV2({
  int wins = 1,
  int losses = 0,
  int currentWinStreak = 1,
  int bestWinStreak = 1,
  int totalAttemptsOnWins = 4,
  Map<String, Object?>? byWordLength,
  Map<String, Object?>? byDifficulty,
  List<Map<String, Object?>>? recentGames,
  List<String>? recordedGameIds,
}) {
  final game = _game(id: 'g1', attemptsUsed: 4).toJson();
  return {
    'version': 2,
    'wins': wins,
    'losses': losses,
    'currentWinStreak': currentWinStreak,
    'bestWinStreak': bestWinStreak,
    'totalAttemptsOnWins': totalAttemptsOnWins,
    'byWordLength':
        byWordLength ??
        {
          '5': {'totalGames': 1, 'wins': 1},
        },
    'byDifficulty':
        byDifficulty ??
        {
          'common': {'totalGames': 1, 'wins': 1},
        },
    'recentGames': recentGames ?? [game],
    'recordedGameIds': recordedGameIds ?? ['g1'],
  };
}

void main() {
  group('LocalStatisticsRepository.loadSnapshot', () {
    test('returns an empty snapshot when storage is empty', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );
      final snapshot = await repository.loadSnapshot();

      expect(snapshot.totalGames, 0);
      expect(snapshot.recentGames, isEmpty);
    });

    test('throws for malformed JSON', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.statistics: 'not json{{'},
      );
      final repository = LocalStatisticsRepository(store: store);

      await expectLater(
        repository.loadSnapshot(),
        throwsA(isA<StatisticsRepositoryException>()),
      );
    });

    test('throws for an unsupported document version', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.statistics:
              '{"version": 99, "wins": 0, "losses": 0, "currentWinStreak": 0, '
              '"bestWinStreak": 0, "totalAttemptsOnWins": 0, "byWordLength": {}, '
              '"byDifficulty": {}, "recentGames": []}',
        },
      );
      final repository = LocalStatisticsRepository(store: store);

      await expectLater(
        repository.loadSnapshot(),
        throwsA(isA<StatisticsRepositoryException>()),
      );
    });
  });

  group('LocalStatisticsRepository.recordCompletedGame', () {
    test('one win updates totals, streak, and win-attempts total', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );

      final snapshot = await repository.recordCompletedGame(
        _game(id: 'g1', outcome: GameOutcome.won, attemptsUsed: 4),
      );

      expect(snapshot.wins, 1);
      expect(snapshot.losses, 0);
      expect(snapshot.currentWinStreak, 1);
      expect(snapshot.bestWinStreak, 1);
      expect(snapshot.totalAttemptsOnWins, 4);
      expect(snapshot.averageAttemptsOnWins, 4);
    });

    test('one loss updates totals and resets the current streak', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );

      final snapshot = await repository.recordCompletedGame(
        _game(id: 'g1', outcome: GameOutcome.lost, attemptsUsed: 15),
      );

      expect(snapshot.wins, 0);
      expect(snapshot.losses, 1);
      expect(snapshot.currentWinStreak, 0);
      expect(snapshot.bestWinStreak, 0);
      expect(snapshot.totalAttemptsOnWins, 0);
      expect(snapshot.averageAttemptsOnWins, isNull);
    });

    test('multiple games accumulate totals', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );

      await repository.recordCompletedGame(
        _game(id: 'g1', outcome: GameOutcome.won),
      );
      await repository.recordCompletedGame(
        _game(id: 'g2', outcome: GameOutcome.lost),
      );
      final snapshot = await repository.recordCompletedGame(
        _game(id: 'g3', outcome: GameOutcome.won),
      );

      expect(snapshot.totalGames, 3);
      expect(snapshot.wins, 2);
      expect(snapshot.losses, 1);
    });

    test('a win after a loss resets and rebuilds the current streak', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );

      await repository.recordCompletedGame(
        _game(id: 'g1', outcome: GameOutcome.won),
      );
      await repository.recordCompletedGame(
        _game(id: 'g2', outcome: GameOutcome.lost),
      );
      final snapshot = await repository.recordCompletedGame(
        _game(id: 'g3', outcome: GameOutcome.won),
      );

      expect(snapshot.currentWinStreak, 1);
      expect(snapshot.bestWinStreak, 1);
    });

    test('bestWinStreak keeps the highest streak reached', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );

      await repository.recordCompletedGame(
        _game(id: 'g1', outcome: GameOutcome.won),
      );
      await repository.recordCompletedGame(
        _game(id: 'g2', outcome: GameOutcome.won),
      );
      await repository.recordCompletedGame(
        _game(id: 'g3', outcome: GameOutcome.lost),
      );
      final snapshot = await repository.recordCompletedGame(
        _game(id: 'g4', outcome: GameOutcome.won),
      );

      expect(snapshot.currentWinStreak, 1);
      expect(snapshot.bestWinStreak, 2);
    });

    test('averageAttemptsOnWins reflects only won games', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );

      await repository.recordCompletedGame(
        _game(id: 'g1', outcome: GameOutcome.won, attemptsUsed: 2),
      );
      await repository.recordCompletedGame(
        _game(id: 'g2', outcome: GameOutcome.lost, attemptsUsed: 15),
      );
      final snapshot = await repository.recordCompletedGame(
        _game(id: 'g3', outcome: GameOutcome.won, attemptsUsed: 6),
      );

      expect(snapshot.averageAttemptsOnWins, 4);
    });

    test('byWordLength breaks totals and wins down per length', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );

      await repository.recordCompletedGame(
        _game(id: 'g1', wordLength: 4, outcome: GameOutcome.won),
      );
      final snapshot = await repository.recordCompletedGame(
        _game(id: 'g2', wordLength: 4, outcome: GameOutcome.lost),
      );

      expect(snapshot.byWordLength[4]!.totalGames, 2);
      expect(snapshot.byWordLength[4]!.wins, 1);
      expect(snapshot.byWordLength.containsKey(5), isFalse);
    });

    test('byDifficulty breaks totals and wins down per difficulty', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );

      await repository.recordCompletedGame(
        _game(
          id: 'g1',
          difficulty: DifficultyOption.hard,
          outcome: GameOutcome.won,
        ),
      );
      final snapshot = await repository.recordCompletedGame(
        _game(
          id: 'g2',
          difficulty: DifficultyOption.hard,
          outcome: GameOutcome.won,
        ),
      );

      expect(snapshot.byDifficulty[DifficultyOption.hard]!.totalGames, 2);
      expect(snapshot.byDifficulty[DifficultyOption.hard]!.wins, 2);
      expect(snapshot.byDifficulty.containsKey(DifficultyOption.easy), isFalse);
    });

    test('recentGames is newest-first', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );

      await repository.recordCompletedGame(_game(id: 'g1'));
      await repository.recordCompletedGame(_game(id: 'g2'));
      final snapshot = await repository.recordCompletedGame(_game(id: 'g3'));

      expect(snapshot.recentGames.map((g) => g.id), ['g3', 'g2', 'g1']);
    });

    test('recentGames is truncated without losing aggregate totals', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );
      var snapshot = await repository.loadSnapshot();

      for (var i = 0; i < maxRecentGames + 5; i++) {
        snapshot = await repository.recordCompletedGame(
          _game(id: 'g$i', outcome: GameOutcome.won),
        );
      }

      expect(snapshot.recentGames.length, maxRecentGames);
      expect(snapshot.totalGames, maxRecentGames + 5);
      expect(snapshot.wins, maxRecentGames + 5);
    });

    test('a duplicate result ID is ignored', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );
      await repository.recordCompletedGame(
        _game(id: 'g1', outcome: GameOutcome.won),
      );

      final snapshot = await repository.recordCompletedGame(
        _game(id: 'g1', outcome: GameOutcome.won),
      );

      expect(snapshot.totalGames, 1);
      expect(snapshot.recentGames.length, 1);
    });

    test('a duplicate result ID does not write to storage again', () async {
      final store = FakePreferencesStore();
      final repository = LocalStatisticsRepository(store: store);
      await repository.recordCompletedGame(_game(id: 'g1'));

      final writesBefore = store.setStringCalls.length;
      await repository.recordCompletedGame(_game(id: 'g1'));

      expect(store.setStringCalls.length, writesBefore);
    });

    test('a write failure propagates and does not claim success', () async {
      final store = FakePreferencesStore()..failSetString = true;
      final repository = LocalStatisticsRepository(store: store);

      await expectLater(
        repository.recordCompletedGame(_game(id: 'g1')),
        throwsA(isA<Exception>()),
      );

      final reloaded = await LocalStatisticsRepository(
        store: FakePreferencesStore(initialValues: store.values),
      ).loadSnapshot();
      expect(reloaded.totalGames, 0);
    });

    test('persisted data round-trips through JSON', () async {
      final store = FakePreferencesStore();
      final repository = LocalStatisticsRepository(store: store);
      await repository.recordCompletedGame(
        _game(id: 'g1', wordLength: 6, difficulty: DifficultyOption.easy),
      );

      final reloadedRepository = LocalStatisticsRepository(store: store);
      final snapshot = await reloadedRepository.loadSnapshot();

      expect(snapshot.totalGames, 1);
      expect(snapshot.recentGames.single.id, 'g1');
      expect(snapshot.recentGames.single.wordLength, 6);
      expect(snapshot.recentGames.single.difficulty, DifficultyOption.easy);
    });
  });

  group('LocalStatisticsRepository.clearStatistics', () {
    test('resets to an empty snapshot', () async {
      final store = FakePreferencesStore();
      final repository = LocalStatisticsRepository(store: store);
      await repository.recordCompletedGame(_game(id: 'g1'));

      final snapshot = await repository.clearStatistics();

      expect(snapshot.totalGames, 0);
      final reloaded = await repository.loadSnapshot();
      expect(reloaded.totalGames, 0);
    });

    test('does not remove the theme preference key', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.themePreference: 'dark'},
      );
      final repository = LocalStatisticsRepository(store: store);
      await repository.recordCompletedGame(_game(id: 'g1'));

      await repository.clearStatistics();

      expect(store.values[StorageKeys.themePreference], 'dark');
    });

    test('succeeds against malformed stored data without needing to decode it '
        'first', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.statistics: 'not json{{'},
      );
      final repository = LocalStatisticsRepository(store: store);

      final snapshot = await repository.clearStatistics();

      expect(snapshot.totalGames, 0);
      final reloaded = await repository.loadSnapshot();
      expect(reloaded.totalGames, 0);
    });
  });

  group('LocalStatisticsRepository operation serialization', () {
    test('A: two simultaneously requested records both remain in '
        'aggregates', () async {
      final store = FakePreferencesStore();
      final gate = Completer<void>();
      store.getStringGate = gate;
      final repository = LocalStatisticsRepository(store: store);

      final futureA = repository.recordCompletedGame(
        _game(id: 'gameA', outcome: GameOutcome.won),
      );
      final futureB = repository.recordCompletedGame(
        _game(id: 'gameB', outcome: GameOutcome.lost),
      );

      // Release both operations' (queued, not interleaved) reads together —
      // if they were not serialized, both would see the same pre-write
      // document and one write would clobber the other.
      gate.complete();
      await Future.wait([futureA, futureB]);

      final snapshot = await repository.loadSnapshot();
      expect(snapshot.wins, 1);
      expect(snapshot.losses, 1);
      expect(snapshot.totalGames, 2);
      expect(snapshot.recentGames.map((g) => g.id).toSet(), {'gameA', 'gameB'});
    });

    test('B: record then Clear finishes with empty statistics', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );

      final recordFuture = repository.recordCompletedGame(_game(id: 'g1'));
      final clearFuture = repository.clearStatistics();
      await Future.wait([recordFuture, clearFuture]);

      final snapshot = await repository.loadSnapshot();
      expect(snapshot.totalGames, 0);
    });

    test(
      'C: Clear then record finishes with exactly the later record',
      () async {
        final repository = LocalStatisticsRepository(
          store: FakePreferencesStore(),
        );
        await repository.recordCompletedGame(_game(id: 'seed'));

        final clearFuture = repository.clearStatistics();
        final recordFuture = repository.recordCompletedGame(_game(id: 'later'));
        await Future.wait([clearFuture, recordFuture]);

        final snapshot = await repository.loadSnapshot();
        expect(snapshot.totalGames, 1);
        expect(snapshot.recentGames.single.id, 'later');
      },
    );

    test('D: a failed operation does not prevent the next queued operation '
        'from running', () async {
      final store = FakePreferencesStore()..failSetString = true;
      final repository = LocalStatisticsRepository(store: store);

      await expectLater(
        repository.recordCompletedGame(_game(id: 'g1')),
        throwsA(isA<Exception>()),
      );

      store.failSetString = false;
      final snapshot = await repository.recordCompletedGame(_game(id: 'g2'));

      expect(snapshot.recentGames.map((g) => g.id).toList(), ['g2']);
    });
  });

  group('LocalStatisticsRepository durable duplicate-ID tracking', () {
    test('the same ID after 25 or more later games remains ignored', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );
      var snapshot = await repository.recordCompletedGame(
        _game(id: 'original'),
      );
      for (var i = 0; i < 25; i++) {
        snapshot = await repository.recordCompletedGame(_game(id: 'filler$i'));
      }
      expect(snapshot.totalGames, 26);
      expect(snapshot.recentGames.any((g) => g.id == 'original'), isFalse);

      snapshot = await repository.recordCompletedGame(_game(id: 'original'));

      expect(snapshot.totalGames, 26);
    });

    test('the recorded ID set survives a JSON round-trip', () async {
      final store = FakePreferencesStore();
      final repositoryA = LocalStatisticsRepository(store: store);
      await repositoryA.recordCompletedGame(_game(id: 'original'));
      for (var i = 0; i < 25; i++) {
        await repositoryA.recordCompletedGame(_game(id: 'filler$i'));
      }

      // A fresh repository instance backed by the same underlying store,
      // as if the app had restarted.
      final repositoryB = LocalStatisticsRepository(store: store);
      final snapshot = await repositoryB.recordCompletedGame(
        _game(id: 'original'),
      );

      expect(snapshot.totalGames, 26);
    });

    test('a version-1 document loads successfully', () async {
      final v1Json = jsonEncode({
        'version': 1,
        'wins': 1,
        'losses': 0,
        'currentWinStreak': 1,
        'bestWinStreak': 1,
        'totalAttemptsOnWins': 4,
        'byWordLength': {
          '5': {'totalGames': 1, 'wins': 1},
        },
        'byDifficulty': {
          'common': {'totalGames': 1, 'wins': 1},
        },
        'recentGames': [_game(id: 'g1', attemptsUsed: 4).toJson()],
        // No "recordedGameIds" key at all — v1 predates it.
      });
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.statistics: v1Json},
      );
      final repository = LocalStatisticsRepository(store: store);

      final snapshot = await repository.loadSnapshot();

      expect(snapshot.totalGames, 1);
      expect(snapshot.recentGames.single.id, 'g1');
    });

    test('a version-1 mutation writes version 2', () async {
      final v1Json = jsonEncode({
        'version': 1,
        'wins': 1,
        'losses': 0,
        'currentWinStreak': 1,
        'bestWinStreak': 1,
        'totalAttemptsOnWins': 4,
        'byWordLength': {
          '5': {'totalGames': 1, 'wins': 1},
        },
        'byDifficulty': {
          'common': {'totalGames': 1, 'wins': 1},
        },
        'recentGames': [_game(id: 'g1', attemptsUsed: 4).toJson()],
      });
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.statistics: v1Json},
      );
      final repository = LocalStatisticsRepository(store: store);

      await repository.recordCompletedGame(
        _game(id: 'g2', outcome: GameOutcome.lost),
      );

      final storedRaw = store.values[StorageKeys.statistics]!;
      final storedDoc = jsonDecode(storedRaw) as Map<String, Object?>;
      expect(storedDoc['version'], 2);
      expect(storedDoc['recordedGameIds'], containsAll(['g1', 'g2']));

      // The migration also proves itself functionally: re-recording the
      // v1 game's id is still recognized as a duplicate.
      final snapshot = await repository.recordCompletedGame(_game(id: 'g1'));
      expect(snapshot.totalGames, 2);
    });

    test('duplicate ids inside recordedGameIds are rejected', () async {
      final doc = _validDocumentV2(recordedGameIds: ['g1', 'g1']);
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.statistics: jsonEncode(doc)},
      );
      final repository = LocalStatisticsRepository(store: store);

      await expectLater(
        repository.loadSnapshot(),
        throwsA(isA<StatisticsRepositoryException>()),
      );
    });

    test('duplicate ids inside recentGames are rejected', () async {
      final game = _game(id: 'g1', attemptsUsed: 4).toJson();
      final doc = _validDocumentV2(recentGames: [game, game]);
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.statistics: jsonEncode(doc)},
      );
      final repository = LocalStatisticsRepository(store: store);

      await expectLater(
        repository.loadSnapshot(),
        throwsA(isA<StatisticsRepositoryException>()),
      );
    });

    test(
      'every recent-game ID must appear in recordedGameIds for version 2',
      () async {
        final doc = _validDocumentV2(recordedGameIds: ['not-g1']);
        final store = FakePreferencesStore(
          initialValues: {StorageKeys.statistics: jsonEncode(doc)},
        );
        final repository = LocalStatisticsRepository(store: store);

        await expectLater(
          repository.loadSnapshot(),
          throwsA(isA<StatisticsRepositoryException>()),
        );
      },
    );

    test('Clear empties durable IDs, allowing the same ID to be recorded '
        'again', () async {
      final repository = LocalStatisticsRepository(
        store: FakePreferencesStore(),
      );
      await repository.recordCompletedGame(_game(id: 'g1'));

      await repository.clearStatistics();
      final snapshot = await repository.recordCompletedGame(_game(id: 'g1'));

      expect(snapshot.totalGames, 1);
    });
  });

  group('LocalStatisticsRepository persisted-document cross-validation', () {
    test('rejects when byWordLength totalGames sum does not match aggregate '
        'totalGames', () async {
      final doc = _validDocumentV2(
        byWordLength: {
          '5': {'totalGames': 2, 'wins': 1},
        },
      );
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.statistics: jsonEncode(doc)},
      );
      final repository = LocalStatisticsRepository(store: store);

      await expectLater(
        repository.loadSnapshot(),
        throwsA(isA<StatisticsRepositoryException>()),
      );
    });

    test(
      'rejects when byWordLength wins sum does not match aggregate wins',
      () async {
        final doc = _validDocumentV2(
          byWordLength: {
            '5': {'totalGames': 1, 'wins': 0},
          },
        );
        final store = FakePreferencesStore(
          initialValues: {StorageKeys.statistics: jsonEncode(doc)},
        );
        final repository = LocalStatisticsRepository(store: store);

        await expectLater(
          repository.loadSnapshot(),
          throwsA(isA<StatisticsRepositoryException>()),
        );
      },
    );

    test('rejects when byDifficulty totalGames sum does not match aggregate '
        'totalGames', () async {
      final doc = _validDocumentV2(
        byDifficulty: {
          'common': {'totalGames': 2, 'wins': 1},
        },
      );
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.statistics: jsonEncode(doc)},
      );
      final repository = LocalStatisticsRepository(store: store);

      await expectLater(
        repository.loadSnapshot(),
        throwsA(isA<StatisticsRepositoryException>()),
      );
    });

    test(
      'rejects when byDifficulty wins sum does not match aggregate wins',
      () async {
        final doc = _validDocumentV2(
          byDifficulty: {
            'common': {'totalGames': 1, 'wins': 0},
          },
        );
        final store = FakePreferencesStore(
          initialValues: {StorageKeys.statistics: jsonEncode(doc)},
        );
        final repository = LocalStatisticsRepository(store: store);

        await expectLater(
          repository.loadSnapshot(),
          throwsA(isA<StatisticsRepositoryException>()),
        );
      },
    );

    test('missing-entry policy: a category with no persisted breakdown is '
        'treated as zero, not required to be present', () async {
      final doc = _validDocumentV2();
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.statistics: jsonEncode(doc)},
      );
      final repository = LocalStatisticsRepository(store: store);

      final snapshot = await repository.loadSnapshot();

      expect(snapshot.byWordLength.containsKey(4), isFalse);
      expect(snapshot.byWordLength.containsKey(6), isFalse);
      expect(snapshot.byDifficulty.containsKey(DifficultyOption.easy), isFalse);
      expect(snapshot.totalGames, 1);
    });

    test(
      'rejects a byWordLength entry for an unsupported word length',
      () async {
        final doc = _validDocumentV2(
          byWordLength: {
            '7': {'totalGames': 1, 'wins': 1},
          },
        );
        final store = FakePreferencesStore(
          initialValues: {StorageKeys.statistics: jsonEncode(doc)},
        );
        final repository = LocalStatisticsRepository(store: store);

        await expectLater(
          repository.loadSnapshot(),
          throwsA(isA<StatisticsRepositoryException>()),
        );
      },
    );

    test(
      'rejects a byDifficulty entry for an unrecognized difficulty',
      () async {
        final doc = _validDocumentV2(
          byDifficulty: {
            'extreme': {'totalGames': 1, 'wins': 1},
          },
        );
        final store = FakePreferencesStore(
          initialValues: {StorageKeys.statistics: jsonEncode(doc)},
        );
        final repository = LocalStatisticsRepository(store: store);

        await expectLater(
          repository.loadSnapshot(),
          throwsA(isA<StatisticsRepositoryException>()),
        );
      },
    );

    test('does not require recentGames length to equal totalGames', () async {
      final doc = _validDocumentV2(
        wins: 5,
        losses: 0,
        currentWinStreak: 5,
        bestWinStreak: 5,
        totalAttemptsOnWins: 20,
        byWordLength: {
          '5': {'totalGames': 5, 'wins': 5},
        },
        byDifficulty: {
          'common': {'totalGames': 5, 'wins': 5},
        },
        recentGames: [_game(id: 'g1', attemptsUsed: 4).toJson()],
        recordedGameIds: ['g1', 'g2', 'g3', 'g4', 'g5'],
      );
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.statistics: jsonEncode(doc)},
      );
      final repository = LocalStatisticsRepository(store: store);

      final snapshot = await repository.loadSnapshot();

      expect(snapshot.totalGames, 5);
      expect(snapshot.recentGames.length, 1);
    });
  });
}
