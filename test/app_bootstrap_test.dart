import 'package:cowbullgame/app_bootstrap.dart';
import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/coin_wallet.dart';
import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppBootstrap.load', () {
    test(
      'defaults to the Dark theme preference when nothing is stored',
      () async {
        final bootstrap = await AppBootstrap.load();
        expect(bootstrap.settings.themePreference, AppThemePreference.dark);
      },
    );

    test('restores a persisted dark theme preference', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.themePreference: 'dark',
      });
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.settings.themePreference, AppThemePreference.dark);
    });

    test('builds a functional statistics repository', () async {
      final bootstrap = await AppBootstrap.load();
      final snapshot = await bootstrap.statisticsRepository.loadSnapshot();
      expect(snapshot.totalGames, 0);
    });

    test(
      'defaults to the starting coin balance when nothing is stored',
      () async {
        final bootstrap = await AppBootstrap.load();
        expect(bootstrap.coinWallet.balance, startingCoinBalance);
      },
    );

    test('restores a persisted coin balance', () async {
      SharedPreferences.setMockInitialValues({StorageKeys.coinBalance: '42'});
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.coinWallet.balance, 42);
    });

    test(
      'defaults the audio feedback preferences when nothing is stored',
      () async {
        final bootstrap = await AppBootstrap.load();
        expect(bootstrap.audioFeedbackSettings.soundEffectsEnabled, isTrue);
        expect(bootstrap.audioFeedbackSettings.musicEnabled, isFalse);
        expect(bootstrap.audioFeedbackSettings.hapticsEnabled, isTrue);
      },
    );

    test('restores persisted audio feedback preferences', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.soundEffectsEnabled: 'false',
        StorageKeys.musicEnabled: 'true',
        StorageKeys.hapticsEnabled: 'false',
      });
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.audioFeedbackSettings.soundEffectsEnabled, isFalse);
      expect(bootstrap.audioFeedbackSettings.musicEnabled, isTrue);
      expect(bootstrap.audioFeedbackSettings.hapticsEnabled, isFalse);
    });

    test(
      'builds an audio feedback coordinator wired to the same settings',
      () async {
        final bootstrap = await AppBootstrap.load();
        bootstrap.audioFeedbackSettings.setHapticsEnabled(false);
        // No exception means the coordinator observed the change without
        // throwing; deeper behavior is covered by
        // audio_feedback_coordinator_test.dart.
        expect(bootstrap.audioFeedback, isNotNull);
      },
    );
  });

  group('AppBootstrap.resetLocalData', () {
    test('removes the theme preference, statistics, coin balance, and audio '
        'feedback keys', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.themePreference: 'dark',
          StorageKeys.statistics: '{"whatever":true}',
          StorageKeys.coinBalance: '80',
          StorageKeys.soundEffectsEnabled: 'false',
          StorageKeys.musicEnabled: 'true',
          StorageKeys.hapticsEnabled: 'false',
        },
      );

      await AppBootstrap.resetLocalData(store);

      expect(store.values.containsKey(StorageKeys.themePreference), isFalse);
      expect(store.values.containsKey(StorageKeys.statistics), isFalse);
      expect(store.values.containsKey(StorageKeys.coinBalance), isFalse);
      expect(
        store.values.containsKey(StorageKeys.soundEffectsEnabled),
        isFalse,
      );
      expect(store.values.containsKey(StorageKeys.musicEnabled), isFalse);
      expect(store.values.containsKey(StorageKeys.hapticsEnabled), isFalse);
    });

    test('leaves any other key untouched', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.themePreference: 'dark',
          StorageKeys.statistics: '{"whatever":true}',
          StorageKeys.coinBalance: '80',
          'unrelated_key': 'keep-me',
        },
      );

      await AppBootstrap.resetLocalData(store);

      expect(store.values['unrelated_key'], 'keep-me');
    });

    test('does not throw when none of the keys were ever set', () async {
      final store = FakePreferencesStore();

      await expectLater(AppBootstrap.resetLocalData(store), completes);
    });
  });
}
