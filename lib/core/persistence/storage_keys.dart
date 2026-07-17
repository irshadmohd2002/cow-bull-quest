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

  /// The persisted coin balance string value (see `coin_wallet.dart`).
  static const String coinBalance = 'coin_balance';

  /// The persisted sound-effects-enabled `'true'`/`'false'` value (see
  /// `audio_feedback_settings.dart`).
  static const String soundEffectsEnabled = 'sound_effects_enabled';

  /// The persisted background-music-enabled `'true'`/`'false'` value (see
  /// `audio_feedback_settings.dart`).
  static const String musicEnabled = 'music_enabled';

  /// The persisted haptic-feedback-enabled `'true'`/`'false'` value (see
  /// `audio_feedback_settings.dart`).
  static const String hapticsEnabled = 'haptics_enabled';

  /// The persisted, versioned daily-streak JSON document (see
  /// `features/streak/data/local_streak_repository.dart`).
  static const String streak = 'daily_streak';

  /// The persisted, versioned Daily Challenge results JSON document (see
  /// `features/daily_challenge/data/local_daily_challenge_repository.dart`).
  static const String dailyChallengeResults = 'daily_challenge_results';
}
