import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/daily_challenge/data/local_daily_challenge_repository.dart';
import 'package:cowbullgame/features/daily_challenge/models/daily_challenge_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_preferences_store.dart';

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
  group('LocalDailyChallengeRepository', () {
    test('loadResult returns null when nothing is stored', () async {
      final repository = LocalDailyChallengeRepository(
        store: FakePreferencesStore(),
      );
      expect(
        await repository.loadResult(LocalDate(year: 2026, month: 7, day: 18)),
        isNull,
      );
    });

    test('recordIfFirst stores and loadResult returns it back', () async {
      final repository = LocalDailyChallengeRepository(
        store: FakePreferencesStore(),
      );
      final date = LocalDate(year: 2026, month: 7, day: 18);
      final result = _result(date);
      await repository.recordIfFirst(result);
      expect(await repository.loadResult(date), result);
    });

    test(
      'a second recordIfFirst for the same date never overwrites the first',
      () async {
        final repository = LocalDailyChallengeRepository(
          store: FakePreferencesStore(),
        );
        final date = LocalDate(year: 2026, month: 7, day: 18);
        final official = _result(date, attemptsUsed: 3);
        final replay = _result(date, attemptsUsed: 7, won: false);

        final firstReturn = await repository.recordIfFirst(official);
        final secondReturn = await repository.recordIfFirst(replay);

        expect(firstReturn, official);
        expect(secondReturn, official);
        expect(await repository.loadResult(date), official);
      },
    );

    test('results for different dates are stored independently', () async {
      final repository = LocalDailyChallengeRepository(
        store: FakePreferencesStore(),
      );
      final day1 = LocalDate(year: 2026, month: 7, day: 18);
      final day2 = LocalDate(year: 2026, month: 7, day: 19);
      await repository.recordIfFirst(_result(day1));
      await repository.recordIfFirst(_result(day2, won: false));

      expect((await repository.loadResult(day1))!.won, isTrue);
      expect((await repository.loadResult(day2))!.won, isFalse);
    });

    test(
      'reload after persistence preserves the recorded result (survives reload)',
      () async {
        final store = FakePreferencesStore();
        final date = LocalDate(year: 2026, month: 7, day: 18);
        await LocalDailyChallengeRepository(
          store: store,
        ).recordIfFirst(_result(date));

        final reloaded = LocalDailyChallengeRepository(store: store);
        expect(await reloaded.loadResult(date), _result(date));
      },
    );

    test('clear removes every stored result and nothing else', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.coinBalance: '100'},
      );
      final repository = LocalDailyChallengeRepository(store: store);
      final date = LocalDate(year: 2026, month: 7, day: 18);
      await repository.recordIfFirst(_result(date));

      await repository.clear();

      expect(await repository.loadResult(date), isNull);
      expect(store.values[StorageKeys.coinBalance], '100');
    });

    test('loadResult recovers safely from malformed top-level JSON', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.dailyChallengeResults: 'not json'},
      );
      final repository = LocalDailyChallengeRepository(store: store);
      expect(
        await repository.loadResult(LocalDate(year: 2026, month: 7, day: 18)),
        isNull,
      );
    });

    test(
      'one malformed entry does not invalidate other valid entries',
      () async {
        final store = FakePreferencesStore();
        final date = LocalDate(year: 2026, month: 7, day: 18);
        final repository = LocalDailyChallengeRepository(store: store);
        await repository.recordIfFirst(_result(date));

        // Corrupt the stored document by hand-inserting a malformed entry
        // alongside the valid one already written above.
        final raw = store.values[StorageKeys.dailyChallengeResults]!;
        final corrupted = raw.replaceFirst(
          '"results":{',
          '"results":{"2026-07-19":{"bogus":true},',
        );
        await store.setString(StorageKeys.dailyChallengeResults, corrupted);

        final reloaded = LocalDailyChallengeRepository(store: store);
        expect(await reloaded.loadResult(date), isNotNull);
      },
    );
  });
}
