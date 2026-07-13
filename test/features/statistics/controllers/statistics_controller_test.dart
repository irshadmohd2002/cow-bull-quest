import 'dart:async';

import 'package:cowbullgame/features/statistics/controllers/statistics_controller.dart';
import 'package:cowbullgame/features/statistics/controllers/statistics_controller_state.dart';
import 'package:cowbullgame/features/statistics/models/completed_game.dart';
import 'package:cowbullgame/features/statistics/models/game_outcome.dart';
import 'package:cowbullgame/models/difficulty_selection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_statistics_repository.dart';

CompletedGame _game(String id, {GameOutcome outcome = GameOutcome.won}) =>
    CompletedGame(
      id: id,
      completedAt: DateTime.utc(2026, 1, 1),
      wordLength: 5,
      difficulty: DifficultyOption.common,
      outcome: outcome,
      attemptsUsed: 3,
      maxAttempts: 15,
    );

void main() {
  test('the initial state is loading', () {
    final controller = StatisticsController(
      repository: FakeStatisticsRepository(),
    );
    expect(controller.state, isA<StatisticsLoading>());
  });

  group('StatisticsController.load', () {
    test('transitions to ready with the loaded snapshot', () async {
      final repository = FakeStatisticsRepository();
      final controller = StatisticsController(repository: repository);

      await controller.load();

      expect(controller.state, isA<StatisticsReady>());
    });

    test(
      'transitions to failure with no last snapshot on first failure',
      () async {
        final repository = FakeStatisticsRepository()..failLoad = true;
        final controller = StatisticsController(repository: repository);

        await controller.load();

        final state = controller.state;
        expect(state, isA<StatisticsFailure>());
        expect((state as StatisticsFailure).lastSnapshot, isNull);
      },
    );

    test(
      'a later failure keeps the last successfully loaded snapshot',
      () async {
        final repository = FakeStatisticsRepository();
        final controller = StatisticsController(repository: repository);
        await controller.load();
        final readySnapshot = (controller.state as StatisticsReady).snapshot;

        repository.failLoad = true;
        await controller.load();

        final state = controller.state;
        expect(state, isA<StatisticsFailure>());
        expect((state as StatisticsFailure).lastSnapshot, readySnapshot);
      },
    );
  });

  group('StatisticsController.recordCompletedGame', () {
    test('transitions to ready with the updated snapshot', () async {
      final repository = FakeStatisticsRepository();
      final controller = StatisticsController(repository: repository);

      await controller.recordCompletedGame(_game('g1'));

      final state = controller.state;
      expect(state, isA<StatisticsReady>());
      expect((state as StatisticsReady).snapshot.totalGames, 1);
    });

    test('a failure surfaces without claiming success', () async {
      final repository = FakeStatisticsRepository()..failRecord = true;
      final controller = StatisticsController(repository: repository);

      await controller.recordCompletedGame(_game('g1'));

      expect(controller.state, isA<StatisticsFailure>());
    });
  });

  group('StatisticsController.clear', () {
    test('transitions to ready with an empty snapshot', () async {
      final repository = FakeStatisticsRepository();
      final controller = StatisticsController(repository: repository);
      await controller.recordCompletedGame(_game('g1'));

      await controller.clear();

      final state = controller.state;
      expect(state, isA<StatisticsReady>());
      expect((state as StatisticsReady).snapshot.totalGames, 0);
    });

    test('succeeds and recovers even after a prior load failure', () async {
      final repository = FakeStatisticsRepository()..failLoad = true;
      final controller = StatisticsController(repository: repository);
      await controller.load();
      expect(controller.state, isA<StatisticsFailure>());

      repository.failLoad = false;
      await controller.clear();

      final state = controller.state;
      expect(state, isA<StatisticsReady>());
      expect((state as StatisticsReady).snapshot.totalGames, 0);
    });
  });

  group('StatisticsController stale-result handling', () {
    test('a slow load superseded by clear does not overwrite the newer '
        'state', () async {
      final repository = FakeStatisticsRepository();
      final controller = StatisticsController(repository: repository);
      await controller.recordCompletedGame(_game('g1'));

      final gate = Completer<void>();
      repository.gate = gate;
      final staleLoad = controller.load();

      repository.gate = null;
      await controller.clear();
      gate.complete();
      await staleLoad;

      final state = controller.state;
      expect(state, isA<StatisticsReady>());
      expect((state as StatisticsReady).snapshot.totalGames, 0);
    });
  });

  group('StatisticsController notifications', () {
    test('notifies listeners on load completion', () async {
      final controller = StatisticsController(
        repository: FakeStatisticsRepository(),
      );
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.load();

      expect(notifyCount, greaterThan(0));
    });
  });

  group('StatisticsController disposal', () {
    test('disposing does not throw', () {
      final controller = StatisticsController(
        repository: FakeStatisticsRepository(),
      );
      expect(controller.dispose, returnsNormally);
    });

    test('operations after disposal do not throw or notify', () async {
      final controller = StatisticsController(
        repository: FakeStatisticsRepository(),
      );
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.dispose();

      await controller.load();

      expect(notifyCount, 0);
    });
  });
}
