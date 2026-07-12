import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// The user's preferred app theme brightness.
///
/// [system] follows the platform's current brightness; [light] and [dark]
/// force a specific brightness regardless of the platform setting. Carries
/// no human-facing text — presentation code owns how each value is labeled.
enum AppThemePreference {
  system,
  light,
  dark;

  /// The [ThemeMode] `MaterialApp.themeMode` should use for this preference.
  ThemeMode get themeMode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
}

/// App-wide, in-memory settings shared by the whole `MaterialApp`.
///
/// Extends [ChangeNotifier] — the same pattern `GameController` uses for
/// shared, observable state per this project's state-management guidance
/// (see CLAUDE.md) — rather than a full state-management package. Holds
/// only [themePreference]; there is deliberately no persistence, no
/// feature-specific state, and no human-facing strings here. [CowBullApp]
/// owns one instance for the app's lifetime and disposes it; the
/// constructor accepts an [initialThemePreference] so tests (or a future
/// persistence layer) can seed a specific starting value without adding a
/// package.
class AppSettings extends ChangeNotifier {
  AppSettings({
    AppThemePreference initialThemePreference = AppThemePreference.system,
  }) : _themePreference = initialThemePreference;

  AppThemePreference _themePreference;
  bool _disposed = false;

  /// The current theme preference.
  AppThemePreference get themePreference => _themePreference;

  /// The [ThemeMode] `MaterialApp.themeMode` should currently use.
  ThemeMode get themeMode => _themePreference.themeMode;

  /// Updates the theme preference to [preference].
  ///
  /// Does nothing — and does not notify listeners — if [preference] equals
  /// the current value, or if this instance has already been [dispose]d.
  void setThemePreference(AppThemePreference preference) {
    if (_disposed || _themePreference == preference) return;
    _themePreference = preference;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
