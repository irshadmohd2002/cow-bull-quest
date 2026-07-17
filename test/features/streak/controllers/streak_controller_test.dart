import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/streak/controllers/streak_controller.dart';
import 'package:cowbullgame/features/streak/data/local_streak_repository.dart';
import 'package:cowbullgame/features/streak/models/streak_state.dart';
import 'package:cowbullgame/features/streak/models/streak_update_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_local_date_provider.dart';
import '../../../support/fake_preferences_store.dart';

LocalDate _d(int year, int month, int day) =>
    LocalDate(year: year, month: month, day: day);

void main() {
  group('StreakController', () {
    test('a fresh install starts at zero on both counters', () async {
      final controller = StreakController(
        clock: FakeLocalDateProvider(_d(2026, 7, 18)),
      );
      expect(controller.state, StreakState.empty());
    });

    test('load() seeds from the repository', () async {
      final store = FakePreferencesStore();
      final repository = LocalStreakRepository(store: store);
      await repository.saveState(
        StreakState(
          currentStreak: 2,
          longestStreak: 4,
          lastQualifyingDate: _d(2026, 7, 17),
        ),
      );
      final controller = await StreakController.load(
        repository: repository,
        clock: FakeLocalDateProvider(_d(2026, 7, 18)),
      );
      expect(controller.state.currentStreak, 2);
      expect(controller.state.longestStreak, 4);
    });

    test(
      'recordQualifyingCompletion starts a streak and notifies listeners',
      () {
        final clock = FakeLocalDateProvider(_d(2026, 7, 18));
        final controller = StreakController(clock: clock);
        var notified = 0;
        controller.addListener(() => notified++);

        final result = controller.recordQualifyingCompletion();

        expect(result, isA<StreakStarted>());
        expect(controller.state.currentStreak, 1);
        expect(notified, 1);
      },
    );

    test('a second completion on the same day does not notify again', () {
      final clock = FakeLocalDateProvider(_d(2026, 7, 18));
      final controller = StreakController(clock: clock);
      controller.recordQualifyingCompletion();

      var notified = 0;
      controller.addListener(() => notified++);
      final result = controller.recordQualifyingCompletion();

      expect(result, isA<StreakAlreadyCounted>());
      expect(notified, 0);
      expect(controller.state.currentStreak, 1);
    });

    test(
      'completions on consecutive days persist the updated streak',
      () async {
        final store = FakePreferencesStore();
        final repository = LocalStreakRepository(store: store);
        final clock = FakeLocalDateProvider(_d(2026, 7, 18));
        final controller = StreakController(
          clock: clock,
          repository: repository,
        );

        controller.recordQualifyingCompletion();
        clock.setToday(_d(2026, 7, 19));
        controller.recordQualifyingCompletion();

        // Persistence is fire-and-forget; wait for it to settle.
        await Future<void>.delayed(Duration.zero);
        final reloaded = await repository.loadState();
        expect(reloaded.currentStreak, 2);
        expect(reloaded.longestStreak, 2);
      },
    );

    test('a storage failure does not throw or block completion recording', () {
      final store = FakePreferencesStore()..failSetString = true;
      final repository = LocalStreakRepository(store: store);
      final controller = StreakController(
        clock: FakeLocalDateProvider(_d(2026, 7, 18)),
        repository: repository,
      );

      expect(() => controller.recordQualifyingCompletion(), returnsNormally);
      expect(controller.state.currentStreak, 1);
    });

    test('a loss still counts as a qualifying completion', () {
      // StreakController has no notion of win/loss at all — the composition
      // root calls recordQualifyingCompletion for any completed game
      // (win or loss), so this simply documents that the controller itself
      // places no such condition on the call.
      final controller = StreakController(
        clock: FakeLocalDateProvider(_d(2026, 7, 18)),
      );
      final result = controller.recordQualifyingCompletion();
      expect(result.state.currentStreak, 1);
    });

    test(
      'restart/abandon never calls recordQualifyingCompletion, so the streak is untouched',
      () {
        final controller = StreakController(
          clock: FakeLocalDateProvider(_d(2026, 7, 18)),
        );
        // No call at all simulates an abandoned/restarted game that never
        // reached GameController.onGameCompleted.
        expect(controller.state, StreakState.empty());
      },
    );
  });
}
