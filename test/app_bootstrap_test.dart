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
  });

  group('AppBootstrap.resetLocalData', () {
    test(
      'removes the theme preference, statistics, and coin balance keys',
      () async {
        final store = FakePreferencesStore(
          initialValues: {
            StorageKeys.themePreference: 'dark',
            StorageKeys.statistics: '{"whatever":true}',
            StorageKeys.coinBalance: '80',
          },
        );

        await AppBootstrap.resetLocalData(store);

        expect(store.values.containsKey(StorageKeys.themePreference), isFalse);
        expect(store.values.containsKey(StorageKeys.statistics), isFalse);
        expect(store.values.containsKey(StorageKeys.coinBalance), isFalse);
      },
    );

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
