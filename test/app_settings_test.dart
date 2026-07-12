import 'package:cowbullgame/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
