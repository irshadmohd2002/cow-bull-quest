import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/daily_challenge/controllers/daily_challenge_controller.dart';
import 'package:cowbullgame/features/daily_challenge/data/local_daily_challenge_repository.dart';
import 'package:cowbullgame/features/daily_challenge/models/daily_challenge_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_local_date_provider.dart';
import '../../../support/fake_preferences_store.dart';

LocalDate _d(int year, int month, int day) =>
    LocalDate(year: year, month: month, day: day);

DailyChallengeResult _result(
  LocalDate date, {
  bool won = true,
  int attemptsUsed = 3,
}) => DailyChallengeResult(
  date: date,
  won: won,
  attemptsUsed: attemptsUsed,
  maxAttempts: 10,
  hintsUsed: 0,
  completedAt: DateTime.utc(date.year, date.month, date.day, 12),
  wordListVersion: 1,
  guesses: const [DailyChallengeGuessRecord(turnNumber: 1, bulls: 1, cows: 1)],
);

void main() {
  group('DailyChallengeController', () {
    test(
      'load() with nothing stored yields no official result today',
      () async {
        final controller = await DailyChallengeController.load(
          repository: LocalDailyChallengeRepository(
            store: FakePreferencesStore(),
          ),
          clock: FakeLocalDateProvider(_d(2026, 7, 18)),
        );
        expect(controller.today, _d(2026, 7, 18));
        expect(controller.officialResultToday, isNull);
      },
    );

    test('load() seeds from an already-recorded result for today', () async {
      final store = FakePreferencesStore();
      final repository = LocalDailyChallengeRepository(store: store);
      final today = _d(2026, 7, 18);
      await repository.recordIfFirst(_result(today));

      final controller = await DailyChallengeController.load(
        repository: repository,
        clock: FakeLocalDateProvider(today),
      );
      expect(controller.officialResultToday, isNotNull);
    });

    test(
      'recordIfFirst records the first completion and notifies listeners',
      () async {
        final store = FakePreferencesStore();
        final repository = LocalDailyChallengeRepository(store: store);
        final today = _d(2026, 7, 18);
        final controller = await DailyChallengeController.load(
          repository: repository,
          clock: FakeLocalDateProvider(today),
        );
        var notified = 0;
        controller.addListener(() => notified++);

        final official = controller.recordIfFirst(
          _result(today, attemptsUsed: 4),
        );

        expect(official.attemptsUsed, 4);
        expect(controller.officialResultToday, official);
        expect(notified, 1);
      },
    );

    test('a replay completion never overwrites the official result', () async {
      final store = FakePreferencesStore();
      final repository = LocalDailyChallengeRepository(store: store);
      final today = _d(2026, 7, 18);
      final controller = await DailyChallengeController.load(
        repository: repository,
        clock: FakeLocalDateProvider(today),
      );

      final official = controller.recordIfFirst(
        _result(today, attemptsUsed: 3),
      );
      var notified = 0;
      controller.addListener(() => notified++);
      final replayReturn = controller.recordIfFirst(
        _result(today, attemptsUsed: 9, won: false),
      );

      expect(replayReturn, official);
      expect(controller.officialResultToday, official);
      expect(notified, 0);
    });

    test(
      'recordIfFirst persists so a fresh load sees the official result',
      () async {
        final store = FakePreferencesStore();
        final repository = LocalDailyChallengeRepository(store: store);
        final today = _d(2026, 7, 18);
        final controller = await DailyChallengeController.load(
          repository: repository,
          clock: FakeLocalDateProvider(today),
        );
        controller.recordIfFirst(_result(today));
        await Future<void>.delayed(Duration.zero);

        final reloaded = await DailyChallengeController.load(
          repository: repository,
          clock: FakeLocalDateProvider(today),
        );
        expect(reloaded.officialResultToday, isNotNull);
      },
    );

    test('refresh() is a no-op when the date has not changed', () async {
      final clock = FakeLocalDateProvider(_d(2026, 7, 18));
      final controller = await DailyChallengeController.load(
        repository: LocalDailyChallengeRepository(
          store: FakePreferencesStore(),
        ),
        clock: clock,
      );
      var notified = 0;
      controller.addListener(() => notified++);
      await controller.refresh();
      expect(notified, 0);
    });

    test('refresh() picks up a new date and its (absent) result', () async {
      final store = FakePreferencesStore();
      final repository = LocalDailyChallengeRepository(store: store);
      final clock = FakeLocalDateProvider(_d(2026, 7, 18));
      final controller = await DailyChallengeController.load(
        repository: repository,
        clock: clock,
      );
      controller.recordIfFirst(_result(_d(2026, 7, 18)));

      clock.setToday(_d(2026, 7, 19));
      await controller.refresh();

      expect(controller.today, _d(2026, 7, 19));
      expect(controller.officialResultToday, isNull);
    });
  });

  group('Milestone 19: completedCount/wonCount', () {
    test('a fresh install starts both counts at zero', () async {
      final controller = await DailyChallengeController.load(
        repository: LocalDailyChallengeRepository(
          store: FakePreferencesStore(),
        ),
        clock: FakeLocalDateProvider(_d(2026, 7, 18)),
      );
      expect(controller.completedCount, 0);
      expect(controller.wonCount, 0);
    });

    test('load() seeds both counts from every past official result, not '
        'just today\'s', () async {
      final store = FakePreferencesStore();
      final repository = LocalDailyChallengeRepository(store: store);
      await repository.recordIfFirst(_result(_d(2026, 7, 16), won: true));
      await repository.recordIfFirst(_result(_d(2026, 7, 17), won: false));

      final controller = await DailyChallengeController.load(
        repository: repository,
        clock: FakeLocalDateProvider(_d(2026, 7, 18)),
      );

      expect(controller.completedCount, 2);
      expect(controller.wonCount, 1);
    });

    test('recordIfFirst increments completedCount, and wonCount only for a '
        'win', () async {
      final controller = await DailyChallengeController.load(
        repository: LocalDailyChallengeRepository(
          store: FakePreferencesStore(),
        ),
        clock: FakeLocalDateProvider(_d(2026, 7, 18)),
      );

      controller.recordIfFirst(_result(_d(2026, 7, 18), won: true));

      expect(controller.completedCount, 1);
      expect(controller.wonCount, 1);
    });

    test('recordIfFirst increments completedCount but not wonCount for a '
        'loss', () async {
      final controller = await DailyChallengeController.load(
        repository: LocalDailyChallengeRepository(
          store: FakePreferencesStore(),
        ),
        clock: FakeLocalDateProvider(_d(2026, 7, 18)),
      );

      controller.recordIfFirst(_result(_d(2026, 7, 18), won: false));

      expect(controller.completedCount, 1);
      expect(controller.wonCount, 0);
    });

    test('a replay never increments either count — only the first '
        'completion per date counts', () async {
      final controller = await DailyChallengeController.load(
        repository: LocalDailyChallengeRepository(
          store: FakePreferencesStore(),
        ),
        clock: FakeLocalDateProvider(_d(2026, 7, 18)),
      );

      controller.recordIfFirst(_result(_d(2026, 7, 18), won: true));
      controller.recordIfFirst(_result(_d(2026, 7, 18), won: false));

      expect(controller.completedCount, 1);
      expect(controller.wonCount, 1);
    });

    test('refresh() (a date change) never alters either count', () async {
      final store = FakePreferencesStore();
      final repository = LocalDailyChallengeRepository(store: store);
      final clock = FakeLocalDateProvider(_d(2026, 7, 18));
      final controller = await DailyChallengeController.load(
        repository: repository,
        clock: clock,
      );
      controller.recordIfFirst(_result(_d(2026, 7, 18), won: true));

      clock.setToday(_d(2026, 7, 19));
      await controller.refresh();

      expect(controller.completedCount, 1);
      expect(controller.wonCount, 1);
    });

    test('a load() failure (corrupted history) falls back to zero counts '
        'rather than throwing', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.dailyChallengeResults: 'not json'},
      );
      final controller = await DailyChallengeController.load(
        repository: LocalDailyChallengeRepository(store: store),
        clock: FakeLocalDateProvider(_d(2026, 7, 18)),
      );
      expect(controller.completedCount, 0);
      expect(controller.wonCount, 0);
    });
  });
}
