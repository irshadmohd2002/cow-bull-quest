import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_preferences_store.dart';

void main() {
  group('AppSettings default', () {
    test('defaults to the system theme preference', () {
      final settings = AppSettings();
      expect(settings.themePreference, AppThemePreference.system);
      expect(settings.themeMode, ThemeMode.system);
    });
  });

  group('AppSettings.setThemePreference', () {
    test('setting light updates the theme preference and mode', () {
      final settings = AppSettings();
      settings.setThemePreference(AppThemePreference.light);
      expect(settings.themePreference, AppThemePreference.light);
      expect(settings.themeMode, ThemeMode.light);
    });

    test('setting dark updates the theme preference and mode', () {
      final settings = AppSettings();
      settings.setThemePreference(AppThemePreference.dark);
      expect(settings.themePreference, AppThemePreference.dark);
      expect(settings.themeMode, ThemeMode.dark);
    });

    test('changing the preference notifies listeners', () {
      final settings = AppSettings();
      var notifyCount = 0;
      settings.addListener(() => notifyCount++);

      settings.setThemePreference(AppThemePreference.dark);
      expect(notifyCount, 1);

      settings.setThemePreference(AppThemePreference.light);
      expect(notifyCount, 2);
    });

    test('setting the same preference again does not notify', () {
      final settings = AppSettings();
      var notifyCount = 0;
      settings.addListener(() => notifyCount++);

      settings.setThemePreference(AppThemePreference.system);
      expect(notifyCount, 0);

      settings.setThemePreference(AppThemePreference.dark);
      expect(notifyCount, 1);

      settings.setThemePreference(AppThemePreference.dark);
      expect(notifyCount, 1);
    });
  });

  group('AppSettings.load', () {
    // The four scenarios Milestone 13 requires: a first-time install (no
    // saved preference) must default to Dark, while every existing user's
    // already-saved choice — Light, Dark, or System — is restored verbatim
    // and never overwritten by that default.
    test('no saved preference defaults to Dark (first-time install)', () async {
      final settings = await AppSettings.load(FakePreferencesStore());
      expect(settings.themePreference, AppThemePreference.dark);
      expect(settings.themeMode, ThemeMode.dark);
    });

    test('a saved Light preference is restored as Light', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.themePreference: 'light'},
      );
      final settings = await AppSettings.load(store);
      expect(settings.themePreference, AppThemePreference.light);
    });

    test('a saved Dark preference is restored as Dark', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.themePreference: 'dark'},
      );
      final settings = await AppSettings.load(store);
      expect(settings.themePreference, AppThemePreference.dark);
    });

    test('a saved System preference is restored as System', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.themePreference: 'system'},
      );
      final settings = await AppSettings.load(store);
      expect(settings.themePreference, AppThemePreference.system);
    });

    test('falls back to Dark for an unrecognized persisted value', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.themePreference: 'sepia'},
      );
      final settings = await AppSettings.load(store);
      expect(settings.themePreference, AppThemePreference.dark);
    });

    test('falls back to Dark when reading fails', () async {
      final store = FakePreferencesStore()..failGetString = true;
      final settings = await AppSettings.load(store);
      expect(settings.themePreference, AppThemePreference.dark);
    });

    test('loading never writes the Dark default back to storage — an '
        'unrelated later read still sees nothing saved', () async {
      final store = FakePreferencesStore();
      await AppSettings.load(store);
      expect(store.setStringCalls, isEmpty);
      expect(store.values.containsKey(StorageKeys.themePreference), isFalse);
    });
  });

  group('AppSettings persistence on change', () {
    test(
      'persists the new value using a stable string, not the enum index',
      () async {
        final store = FakePreferencesStore();
        final settings = AppSettings(store: store);

        settings.setThemePreference(AppThemePreference.dark);
        await Future<void>.delayed(Duration.zero);

        expect(store.values[StorageKeys.themePreference], 'dark');
      },
    );

    test(
      'setting the same preference again does not write to storage',
      () async {
        final store = FakePreferencesStore();
        final settings = AppSettings(store: store);

        settings.setThemePreference(AppThemePreference.system);
        await Future<void>.delayed(Duration.zero);

        expect(store.setStringCalls, isEmpty);
      },
    );

    test(
      'a persistence failure does not revert the in-memory selection',
      () async {
        final store = FakePreferencesStore()..failSetString = true;
        final settings = AppSettings(store: store);

        settings.setThemePreference(AppThemePreference.dark);
        await Future<void>.delayed(Duration.zero);

        expect(settings.themePreference, AppThemePreference.dark);
        expect(settings.themeMode, ThemeMode.dark);
        expect(settings.debugLastPersistError, isNotNull);
      },
    );

    test('updates the in-memory selection immediately, before the write '
        'completes', () {
      final store = FakePreferencesStore();
      final settings = AppSettings(store: store);

      settings.setThemePreference(AppThemePreference.dark);

      expect(settings.themePreference, AppThemePreference.dark);
    });

    test('without a store, changes remain in-memory only', () async {
      final settings = AppSettings();
      settings.setThemePreference(AppThemePreference.dark);
      await Future<void>.delayed(Duration.zero);

      expect(settings.themePreference, AppThemePreference.dark);
    });
  });

  group('AppSettings persistence write ordering', () {
    test('a reverse-completion fake store cannot reorder the persisted '
        'preference', () async {
      final store = FakePreferencesStore()
        ..setStringDelays['dark'] = const Duration(milliseconds: 50);
      final settings = AppSettings(store: store);

      settings.setThemePreference(AppThemePreference.dark);
      settings.setThemePreference(AppThemePreference.light);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(store.values[StorageKeys.themePreference], 'light');
    });

    test('a failure followed by a success clears the error', () async {
      final store = FakePreferencesStore()..failSetString = true;
      final settings = AppSettings(store: store);

      settings.setThemePreference(AppThemePreference.dark);
      await Future<void>.delayed(Duration.zero);
      expect(settings.debugLastPersistError, isNotNull);

      store.failSetString = false;
      settings.setThemePreference(AppThemePreference.light);
      await Future<void>.delayed(Duration.zero);

      expect(settings.debugLastPersistError, isNull);
    });

    test('a success followed by a failure stores the latest in-memory '
        'preference while exposing the failure', () async {
      final store = FakePreferencesStore();
      final settings = AppSettings(store: store);

      settings.setThemePreference(AppThemePreference.dark);
      await Future<void>.delayed(Duration.zero);
      expect(store.values[StorageKeys.themePreference], 'dark');

      store.failSetString = true;
      settings.setThemePreference(AppThemePreference.light);
      await Future<void>.delayed(Duration.zero);

      expect(settings.themePreference, AppThemePreference.light);
      expect(settings.debugLastPersistError, isNotNull);
      // The failed write never landed, so the store still holds the
      // last value that was actually written successfully.
      expect(store.values[StorageKeys.themePreference], 'dark');
    });

    test('rapid system -> dark -> light writes finish as light', () async {
      final store = FakePreferencesStore()
        ..setStringDelays['dark'] = const Duration(milliseconds: 30);
      final settings = AppSettings(store: store);
      expect(settings.themePreference, AppThemePreference.system);

      settings.setThemePreference(AppThemePreference.dark);
      settings.setThemePreference(AppThemePreference.light);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(store.values[StorageKeys.themePreference], 'light');
    });

    test('each write begins only after the previous one settles', () async {
      final store = FakePreferencesStore();
      final settings = AppSettings(store: store);

      settings.setThemePreference(AppThemePreference.dark);
      settings.setThemePreference(AppThemePreference.light);
      settings.setThemePreference(AppThemePreference.system);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(store.setStringCalls.length, 3);
      expect(store.values[StorageKeys.themePreference], 'system');
    });
  });

  group('AppSettings disposal', () {
    test('disposing does not throw', () {
      final settings = AppSettings();
      expect(settings.dispose, returnsNormally);
    });

    test('setting a preference after disposal does not throw or notify', () {
      final settings = AppSettings();
      var notifyCount = 0;
      settings.addListener(() => notifyCount++);
      settings.dispose();

      expect(
        () => settings.setThemePreference(AppThemePreference.dark),
        returnsNormally,
      );
      expect(notifyCount, 0);
    });
  });
}
