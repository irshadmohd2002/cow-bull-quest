/// Centralized local-storage keys for every value this app persists.
///
/// Keeping every key in one place avoids typos and accidental collisions
/// between unrelated persisted values reading or writing the wrong key.
abstract final class StorageKeys {
  /// The persisted [AppThemePreference] string value (see `app_settings.dart`).
  static const String themePreference = 'theme_preference';

  /// The persisted, versioned statistics JSON document (see
  /// `features/statistics/data/statistics_repository.dart`).
  static const String statistics = 'statistics';
}
