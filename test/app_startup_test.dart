import 'dart:async';

import 'package:cowbullgame/app_bootstrap.dart';
import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/app_startup.dart';
import 'package:cowbullgame/audio_feedback_coordinator.dart';
import 'package:cowbullgame/audio_feedback_settings.dart';
import 'package:cowbullgame/coin_wallet.dart';
import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/daily_challenge/controllers/daily_challenge_controller.dart';
import 'package:cowbullgame/features/onboarding/controllers/onboarding_controller.dart';
import 'package:cowbullgame/features/streak/controllers/streak_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_audio_service.dart';
import 'support/fake_haptic_service.dart';
import 'support/fake_local_date_provider.dart';
import 'support/fake_preferences_store.dart';
import 'support/fake_statistics_repository.dart';

Future<AppBootstrap> _succeedingLoader() async {
  final audioFeedbackSettings = AudioFeedbackSettings();
  final clock = FakeLocalDateProvider(LocalDate(year: 2026, month: 7, day: 18));
  return AppBootstrap(
    settings: AppSettings(),
    statisticsRepository: FakeStatisticsRepository(),
    coinWallet: CoinWallet(),
    audioFeedbackSettings: audioFeedbackSettings,
    audioFeedback: AudioFeedbackCoordinator(
      audioService: FakeAudioService(),
      hapticService: FakeHapticService(),
      settings: audioFeedbackSettings,
    ),
    clock: clock,
    streakController: StreakController(clock: clock),
    dailyChallengeController: DailyChallengeController(clock: clock),
    onboardingController: OnboardingController(initialCompleted: true),
  );
}

void main() {
  testWidgets('a successful startup shows Home', (tester) async {
    await tester.pumpWidget(AppStartup(loadBootstrap: _succeedingLoader));
    await tester.pumpAndSettle();

    expect(find.text('Start Game'), findsOneWidget);
  });

  testWidgets('a bootstrap failure shows a generic, friendly message', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppStartup(
        loadBootstrap: () async =>
            throw StateError('SENTINEL_RAW_STARTUP_ERROR'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Cow Bull Quest couldn't start"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Reset local data'), findsOneWidget);
    expect(find.textContaining('SENTINEL_RAW_STARTUP_ERROR'), findsNothing);
  });

  testWidgets(
    'forcing error details off hides the raw error and the details section',
    (tester) async {
      await tester.pumpWidget(
        AppStartup(
          loadBootstrap: () async =>
              throw StateError('SENTINEL_RAW_STARTUP_ERROR'),
          debugShowErrorDetailsOverride: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Details (debug only)'), findsNothing);
      expect(find.textContaining('SENTINEL_RAW_STARTUP_ERROR'), findsNothing);
    },
  );

  testWidgets('forcing error details on reveals the raw error on demand', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppStartup(
        loadBootstrap: () async =>
            throw StateError('SENTINEL_RAW_STARTUP_ERROR'),
        debugShowErrorDetailsOverride: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Details (debug only)'), findsOneWidget);
    // Not shown yet — the section starts collapsed.
    expect(find.textContaining('SENTINEL_RAW_STARTUP_ERROR'), findsNothing);

    await tester.tap(find.text('Details (debug only)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SENTINEL_RAW_STARTUP_ERROR'), findsOneWidget);
  });

  testWidgets('Retry after a failing-then-succeeding loader reaches Home', (
    tester,
  ) async {
    var callCount = 0;
    Future<AppBootstrap> loader() async {
      callCount++;
      if (callCount == 1) throw StateError('first attempt fails');
      return _succeedingLoader();
    }

    await tester.pumpWidget(AppStartup(loadBootstrap: loader));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Start Game'), findsOneWidget);
    expect(callCount, 2);
  });

  testWidgets(
    'a rapid double-tap on Retry cannot launch an overlapping bootstrap',
    (tester) async {
      var callCount = 0;
      final gate = Completer<void>();
      Future<AppBootstrap> loader() async {
        callCount++;
        if (callCount == 1) throw StateError('first attempt fails');
        await gate.future;
        return _succeedingLoader();
      }

      await tester.pumpWidget(AppStartup(loadBootstrap: loader));
      await tester.pumpAndSettle();
      expect(callCount, 1);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      // The failure screen (and its Retry button) is replaced by the
      // loading screen the instant a retry starts, so there is nothing left
      // to tap a second time — proving the UI itself cannot trigger a
      // second, overlapping load.
      expect(find.text('Retry'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(find.text('Start Game'), findsOneWidget);
    },
  );

  group('AppStartup reset', () {
    testWidgets('cancelling the reset dialog leaves storage untouched', (
      tester,
    ) async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.themePreference: 'dark',
          StorageKeys.statistics: '{"whatever":true}',
          StorageKeys.coinBalance: '80',
          'unrelated_key': 'keep-me',
        },
      );
      await tester.pumpWidget(
        AppStartup(
          loadBootstrap: () async => throw StateError('still broken'),
          resetStore: store,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset local data'));
      await tester.pumpAndSettle();
      expect(find.text('Reset local data?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(store.values[StorageKeys.themePreference], 'dark');
      expect(store.values[StorageKeys.statistics], '{"whatever":true}');
      // Cancelling this explicit full-data-reset dialog must not touch the
      // coin balance either — it stays untouched, same as every other key.
      expect(store.values[StorageKeys.coinBalance], '80');
      expect(store.values['unrelated_key'], 'keep-me');
      expect(find.text("Cow Bull Quest couldn't start"), findsOneWidget);
    });

    testWidgets(
      'confirming reset clears exactly the theme, statistics, and coin '
      'balance keys, leaves other keys untouched, and retries',
      (tester) async {
        final store = FakePreferencesStore(
          initialValues: {
            StorageKeys.themePreference: 'dark',
            StorageKeys.statistics: '{"whatever":true}',
            StorageKeys.coinBalance: '80',
            'unrelated_key': 'keep-me',
          },
        );
        var callCount = 0;
        await tester.pumpWidget(
          AppStartup(
            loadBootstrap: () async {
              callCount++;
              throw StateError('still broken');
            },
            resetStore: store,
          ),
        );
        await tester.pumpAndSettle();
        expect(callCount, 1);

        await tester.ensureVisible(find.text('Reset local data'));
        await tester.tap(find.text('Reset local data'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        expect(store.values.containsKey(StorageKeys.themePreference), isFalse);
        expect(store.values.containsKey(StorageKeys.statistics), isFalse);
        // This IS the explicit full-data-reset action, so — unlike a plain
        // theme change — it is expected/correct for it to also clear
        // earned/remaining coins.
        expect(store.values.containsKey(StorageKeys.coinBalance), isFalse);
        expect(store.values['unrelated_key'], 'keep-me');
        // The initial load plus one retry triggered by the confirmed reset.
        expect(callCount, 2);
      },
    );

    testWidgets('a successful retry after reset reaches Home', (tester) async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.themePreference: 'dark'},
      );
      var callCount = 0;
      Future<AppBootstrap> loader() async {
        callCount++;
        if (callCount == 1) throw StateError('broken until reset');
        return _succeedingLoader();
      }

      await tester.pumpWidget(
        AppStartup(loadBootstrap: loader, resetStore: store),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset local data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.text('Start Game'), findsOneWidget);
      expect(callCount, 2);
    });
  });

  group('Settings-triggered reset (mid-session)', () {
    Future<AppBootstrap> loaderReading(FakePreferencesStore store) async {
      final wallet = await CoinWallet.load(store);
      final clock = FakeLocalDateProvider(
        LocalDate(year: 2026, month: 7, day: 18),
      );
      final audioFeedbackSettings = AudioFeedbackSettings();
      return AppBootstrap(
        settings: AppSettings(),
        statisticsRepository: FakeStatisticsRepository(),
        coinWallet: wallet,
        audioFeedbackSettings: audioFeedbackSettings,
        audioFeedback: AudioFeedbackCoordinator(
          audioService: FakeAudioService(),
          hapticService: FakeHapticService(),
          settings: audioFeedbackSettings,
        ),
        clock: clock,
        streakController: StreakController(clock: clock),
        dailyChallengeController: DailyChallengeController(clock: clock),
        onboardingController: OnboardingController(initialCompleted: true),
      );
    }

    testWidgets(
      'confirming "Reset local data" in Settings clears storage and lands '
      'back on a freshly reloaded Home screen',
      (tester) async {
        final store = FakePreferencesStore(
          initialValues: {
            StorageKeys.coinBalance: '80',
            StorageKeys.themePreference: 'dark',
          },
        );
        var loadCount = 0;
        Future<AppBootstrap> loader() {
          loadCount++;
          return loaderReading(store);
        }

        await tester.pumpWidget(
          AppStartup(loadBootstrap: loader, resetStore: store),
        );
        await tester.pumpAndSettle();
        expect(loadCount, 1);
        expect(find.text('80'), findsOneWidget);

        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Reset local data'));
        await tester.tap(find.text('Reset local data'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        expect(loadCount, 2);
        // CoinWallet.load immediately backfills a fresh default balance the
        // instant it sees a missing one (see its own doc), so `coinBalance`
        // legitimately exists again right after the reload — themePreference
        // is never backfilled that way (AppSettings.load only ever reads a
        // fallback in-memory, never writes it back), so its absence is what
        // actually proves the reset+reload cycle ran.
        expect(store.values.containsKey(StorageKeys.themePreference), isFalse);
        expect(find.text('Start Game'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
      },
    );

    testWidgets('cancelling the Settings reset dialog leaves storage and '
        'the current screen untouched', (tester) async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.coinBalance: '80'},
      );
      var loadCount = 0;
      Future<AppBootstrap> loader() {
        loadCount++;
        return loaderReading(store);
      }

      await tester.pumpWidget(
        AppStartup(loadBootstrap: loader, resetStore: store),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reset local data'));
      await tester.tap(find.text('Reset local data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(loadCount, 1);
      expect(store.values[StorageKeys.coinBalance], '80');
      expect(find.text('Follow system'), findsOneWidget); // still on Settings
    });
  });
}
