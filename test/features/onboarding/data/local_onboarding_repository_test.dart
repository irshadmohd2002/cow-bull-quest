import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:cowbullgame/features/onboarding/data/local_onboarding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_preferences_store.dart';

void main() {
  group('LocalOnboardingRepository', () {
    test('loadCompleted returns null when nothing is stored', () async {
      final repository = LocalOnboardingRepository(
        store: FakePreferencesStore(),
      );
      expect(await repository.loadCompleted(), isNull);
    });

    test('saveCompleted then loadCompleted round-trips true', () async {
      final store = FakePreferencesStore();
      final repository = LocalOnboardingRepository(store: store);
      await repository.saveCompleted(true);
      expect(await repository.loadCompleted(), isTrue);
    });

    test('saveCompleted then loadCompleted round-trips false', () async {
      final store = FakePreferencesStore();
      final repository = LocalOnboardingRepository(store: store);
      await repository.saveCompleted(false);
      expect(await repository.loadCompleted(), isFalse);
    });

    test('loadCompleted recovers safely (returns null) from a malformed '
        'stored value', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.onboardingCompleted: 'not-a-boolean'},
      );
      final repository = LocalOnboardingRepository(store: store);
      expect(await repository.loadCompleted(), isNull);
    });

    test(
      'loadCompleted recovers safely (returns null) from a read failure',
      () async {
        final store = FakePreferencesStore()..failGetString = true;
        final repository = LocalOnboardingRepository(store: store);
        expect(await repository.loadCompleted(), isNull);
      },
    );

    test(
      'clear removes the stored value and never touches other keys',
      () async {
        final store = FakePreferencesStore(
          initialValues: {
            StorageKeys.onboardingCompleted: 'true',
            StorageKeys.coinBalance: '80',
          },
        );
        final repository = LocalOnboardingRepository(store: store);
        await repository.clear();

        expect(
          store.values.containsKey(StorageKeys.onboardingCompleted),
          isFalse,
        );
        expect(store.values[StorageKeys.coinBalance], '80');
      },
    );
  });
}
