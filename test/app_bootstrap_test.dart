import 'package:cowbullgame/app_bootstrap.dart';
import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppBootstrap.load', () {
    test(
      'defaults to the system theme preference when nothing is stored',
      () async {
        final bootstrap = await AppBootstrap.load();
        expect(bootstrap.settings.themePreference, AppThemePreference.system);
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
  });
}
