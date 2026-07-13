import 'dart:async';

import 'package:cowbullgame/app_bootstrap.dart';
import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/app_startup.dart';
import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_preferences_store.dart';
import 'support/fake_statistics_repository.dart';

Future<AppBootstrap> _succeedingLoader() async => AppBootstrap(
  settings: AppSettings(),
  statisticsRepository: FakeStatisticsRepository(),
);

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

    expect(find.text("Cow Bull couldn't start"), findsOneWidget);
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
      expect(store.values['unrelated_key'], 'keep-me');
      expect(find.text("Cow Bull couldn't start"), findsOneWidget);
    });

    testWidgets(
      'confirming reset clears exactly the theme and statistics keys, '
      'leaves other keys untouched, and retries',
      (tester) async {
        final store = FakePreferencesStore(
          initialValues: {
            StorageKeys.themePreference: 'dark',
            StorageKeys.statistics: '{"whatever":true}',
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

        await tester.tap(find.text('Reset local data'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        expect(store.values.containsKey(StorageKeys.themePreference), isFalse);
        expect(store.values.containsKey(StorageKeys.statistics), isFalse);
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
}
