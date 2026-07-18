import 'package:cowbullgame/app_bootstrap.dart';
import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/coin_wallet.dart';
import 'package:cowbullgame/core/persistence/shared_preferences_store.dart';
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

    test('restores persisted lifetime coin totals', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.coinBalance: '42',
        StorageKeys.totalCoinsEarned: '150',
        StorageKeys.totalCoinsSpent: '80',
      });
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.coinWallet.totalCoinsEarned, 150);
      expect(bootstrap.coinWallet.totalCoinsSpent, 80);
    });

    test('a fresh install (predating Milestone 19) starts both coin totals at '
        'zero', () async {
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.coinWallet.totalCoinsEarned, 0);
      expect(bootstrap.coinWallet.totalCoinsSpent, 0);
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

    test(
      'a fresh install starts the streak at zero on both counters',
      () async {
        final bootstrap = await AppBootstrap.load();
        expect(bootstrap.streakController.state.currentStreak, 0);
        expect(bootstrap.streakController.state.longestStreak, 0);
      },
    );

    test('restores a persisted streak', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.streak:
            '{"version":1,"currentStreak":3,"longestStreak":5,'
            '"lastQualifyingDate":"2026-07-17"}',
      });
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.streakController.state.currentStreak, 3);
      expect(bootstrap.streakController.state.longestStreak, 5);
    });

    test(
      "a fresh install has no official Daily Challenge result for today",
      () async {
        final bootstrap = await AppBootstrap.load();
        expect(bootstrap.dailyChallengeController.officialResultToday, isNull);
      },
    );
  });

  group('AppBootstrap.load — onboarding', () {
    test('a genuinely fresh install (nothing stored at all) shows '
        'onboarding', () async {
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.onboardingController.completed, isFalse);
    });

    test('an existing install (already has a coin balance, but no '
        'onboarding flag) is treated as already completed — onboarding is '
        'never forced on a player who already knows the app', () async {
      SharedPreferences.setMockInitialValues({StorageKeys.coinBalance: '80'});
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.onboardingController.completed, isTrue);
    });

    test('an explicitly stored "not completed" flag is restored verbatim, '
        'even on an install that also has a coin balance', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.coinBalance: '80',
        StorageKeys.onboardingCompleted: 'false',
      });
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.onboardingController.completed, isFalse);
    });

    test(
      'an explicitly stored "completed" flag is restored verbatim',
      () async {
        SharedPreferences.setMockInitialValues({
          StorageKeys.onboardingCompleted: 'true',
        });
        final bootstrap = await AppBootstrap.load();
        expect(bootstrap.onboardingController.completed, isTrue);
      },
    );

    test('a malformed stored onboarding value recovers safely, falling back '
        'to the existing-install signal', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.coinBalance: '80',
        StorageKeys.onboardingCompleted: 'not-a-boolean',
      });
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.onboardingController.completed, isTrue);
    });
  });

  group('AppBootstrap.resetLocalData', () {
    test('removes the theme preference, statistics, coin balance, coin '
        'totals, and audio feedback keys', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.themePreference: 'dark',
          StorageKeys.statistics: '{"whatever":true}',
          StorageKeys.coinBalance: '80',
          StorageKeys.totalCoinsEarned: '150',
          StorageKeys.totalCoinsSpent: '70',
          StorageKeys.soundEffectsEnabled: 'false',
          StorageKeys.musicEnabled: 'true',
          StorageKeys.hapticsEnabled: 'false',
        },
      );

      await AppBootstrap.resetLocalData(store);

      expect(store.values.containsKey(StorageKeys.themePreference), isFalse);
      expect(store.values.containsKey(StorageKeys.statistics), isFalse);
      expect(store.values.containsKey(StorageKeys.coinBalance), isFalse);
      expect(store.values.containsKey(StorageKeys.totalCoinsEarned), isFalse);
      expect(store.values.containsKey(StorageKeys.totalCoinsSpent), isFalse);
      expect(
        store.values.containsKey(StorageKeys.soundEffectsEnabled),
        isFalse,
      );
      expect(store.values.containsKey(StorageKeys.musicEnabled), isFalse);
      expect(store.values.containsKey(StorageKeys.hapticsEnabled), isFalse);
    });

    test('removes the streak and Daily Challenge history keys', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.streak:
              '{"version":1,"currentStreak":3,"longestStreak":5,'
              '"lastQualifyingDate":"2026-07-17"}',
          StorageKeys.dailyChallengeResults: '{"version":1,"results":{}}',
        },
      );

      await AppBootstrap.resetLocalData(store);

      expect(store.values.containsKey(StorageKeys.streak), isFalse);
      expect(
        store.values.containsKey(StorageKeys.dailyChallengeResults),
        isFalse,
      );
    });

    test('removes the onboarding-completed key, so a subsequent load shows '
        'onboarding again', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.onboardingCompleted: 'true'},
      );

      await AppBootstrap.resetLocalData(store);

      expect(
        store.values.containsKey(StorageKeys.onboardingCompleted),
        isFalse,
      );
    });

    test('after a full reset, the very next AppBootstrap.load shows '
        'onboarding again — the coin-balance existing-install signal is '
        'also cleared', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.coinBalance: '80',
        StorageKeys.onboardingCompleted: 'true',
      });
      await AppBootstrap.resetLocalData(const SharedPreferencesStore());
      final bootstrap = await AppBootstrap.load();
      expect(bootstrap.onboardingController.completed, isFalse);
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
