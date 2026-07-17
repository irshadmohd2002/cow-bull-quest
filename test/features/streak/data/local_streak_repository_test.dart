import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/streak/data/local_streak_repository.dart';
import 'package:cowbullgame/features/streak/models/streak_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_preferences_store.dart';

void main() {
  group('LocalStreakRepository', () {
    test(
      'loadState returns empty when nothing is stored (fresh install)',
      () async {
        final repository = LocalStreakRepository(store: FakePreferencesStore());
        final state = await repository.loadState();
        expect(state, StreakState.empty());
      },
    );

    test('saveState then loadState round-trips', () async {
      final store = FakePreferencesStore();
      final repository = LocalStreakRepository(store: store);
      final state = StreakState(
        currentStreak: 3,
        longestStreak: 5,
        lastQualifyingDate: LocalDate(year: 2026, month: 7, day: 18),
      );
      await repository.saveState(state);
      expect(await repository.loadState(), state);
    });

    test('loadState recovers safely from malformed JSON', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.streak: 'not json at all'},
      );
      final repository = LocalStreakRepository(store: store);
      expect(await repository.loadState(), StreakState.empty());
    });

    test('loadState recovers safely from an invalid negative streak', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.streak:
              '{"version":1,"currentStreak":-4,"longestStreak":0,'
              '"lastQualifyingDate":null}',
        },
      );
      final repository = LocalStreakRepository(store: store);
      expect(await repository.loadState(), StreakState.empty());
    });

    test('loadState recovers safely from a malformed stored date', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.streak:
              '{"version":1,"currentStreak":1,"longestStreak":1,'
              '"lastQualifyingDate":"not-a-date"}',
        },
      );
      final repository = LocalStreakRepository(store: store);
      expect(await repository.loadState(), StreakState.empty());
    });

    test(
      'loadState recovers safely from an unsupported document version',
      () async {
        final store = FakePreferencesStore(
          initialValues: {
            StorageKeys.streak:
                '{"version":999,"currentStreak":1,"longestStreak":1,'
                '"lastQualifyingDate":null}',
          },
        );
        final repository = LocalStreakRepository(store: store);
        expect(await repository.loadState(), StreakState.empty());
      },
    );

    test('loadState recovers safely from a read failure', () async {
      final store = FakePreferencesStore()..failGetString = true;
      final repository = LocalStreakRepository(store: store);
      expect(await repository.loadState(), StreakState.empty());
    });

    test('clear removes the stored value and nothing else', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.streak:
              '{"version":1,"currentStreak":1,"longestStreak":1,'
              '"lastQualifyingDate":null}',
          StorageKeys.coinBalance: '100',
        },
      );
      final repository = LocalStreakRepository(store: store);
      await repository.clear();
      expect(store.values.containsKey(StorageKeys.streak), isFalse);
      expect(store.values[StorageKeys.coinBalance], '100');
    });
  });
}
