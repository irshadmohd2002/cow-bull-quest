import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'core/persistence/preferences_store.dart';
import 'core/persistence/storage_keys.dart';

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

  /// The stable string this preference is persisted as. Never the enum
  /// index, which is not stable across releases if values are reordered.
  String get _storageValue => switch (this) {
    AppThemePreference.system => 'system',
    AppThemePreference.light => 'light',
    AppThemePreference.dark => 'dark',
  };

  /// Resolves [value] back to an [AppThemePreference]. Any missing or
  /// unrecognized value — including data from a future app version — falls
  /// back to [system] rather than throwing, since a corrupted or unknown
  /// theme preference should never prevent the app from starting.
  static AppThemePreference _fromStorageValue(String? value) => switch (value) {
    'light' => AppThemePreference.light,
    'dark' => AppThemePreference.dark,
    _ => AppThemePreference.system,
  };
}

/// App-wide, in-memory settings shared by the whole `MaterialApp`.
///
/// Extends [ChangeNotifier] — the same pattern `GameController` uses for
/// shared, observable state per this project's state-management guidance
/// (see CLAUDE.md) — rather than a full state-management package. Holds
/// only [themePreference]; there is deliberately no other, feature-specific
/// state and no human-facing strings here. [CowBullApp] owns one instance
/// for the app's lifetime and disposes it; the constructor accepts an
/// [initialThemePreference] so tests (or [load]) can seed a specific
/// starting value.
///
/// If a [PreferencesStore] is supplied, every accepted [setThemePreference]
/// call is persisted to it under [StorageKeys.themePreference] using a
/// stable string value — never the enum index — after updating in-memory
/// state and notifying listeners; a persistence failure never reverts the
/// in-memory selection, since the preference the player just picked should
/// keep applying for the rest of this session regardless of whether the
/// write succeeds. When [store] is omitted, changes remain in-memory only —
/// existing callers/tests that construct `AppSettings()` without a store
/// keep working exactly as before.
///
/// Persistence writes are serialized (see [_enqueuePersist]): each begins
/// only after the previous one has settled, so a rapid sequence of
/// preference changes (e.g. system → dark → light) always finishes
/// persisted as the last one selected, never reordered by however long an
/// individual write happens to take.
class AppSettings extends ChangeNotifier {
  AppSettings({
    AppThemePreference initialThemePreference = AppThemePreference.system,
    PreferencesStore? store,
  }) : _themePreference = initialThemePreference,
       _store = store; // ignore: prefer_initializing_formals

  /// Loads the persisted theme preference from [store] — falling back to
  /// [AppThemePreference.system] if nothing is stored, the stored value is
  /// unrecognized, or reading fails — and returns an [AppSettings] seeded
  /// with it that persists future changes back to the same [store].
  ///
  /// Intended to be `await`-ed during app bootstrap, before the first
  /// frame, so the correct theme is known immediately and the UI never
  /// flashes the default theme before switching to the persisted one.
  static Future<AppSettings> load(PreferencesStore store) async {
    AppThemePreference initial;
    try {
      final stored = await store.getString(StorageKeys.themePreference);
      initial = AppThemePreference._fromStorageValue(stored);
    } on PreferencesStoreException {
      initial = AppThemePreference.system;
    }
    return AppSettings(initialThemePreference: initial, store: store);
  }

  final PreferencesStore? _store;
  AppThemePreference _themePreference;
  bool _disposed = false;

  /// The current theme preference.
  AppThemePreference get themePreference => _themePreference;

  /// The [ThemeMode] `MaterialApp.themeMode` should currently use.
  ThemeMode get themeMode => _themePreference.themeMode;

  /// The error thrown by the most recent persistence attempt, or `null` if
  /// none has failed. Exposed only so tests can assert a write was actually
  /// attempted and failed, rather than silently skipped; not surfaced in the
  /// UI, since a failed preference write is non-fatal — the in-memory
  /// preference the player chose keeps applying regardless.
  @visibleForTesting
  Object? get debugLastPersistError => _lastPersistError;
  Object? _lastPersistError;

  /// The tail of the persistence-write queue. Every accepted preference
  /// change chains its write onto this future and then replaces it with a
  /// failure-swallowing continuation of its own result, so: (a) writes
  /// always begin in the order their preference changes were accepted,
  /// never interleaved or reordered by relative write speed, and (b) one
  /// write failing can never permanently block every later queued write.
  Future<void> _persistTail = Future<void>.value();

  /// Updates the theme preference to [preference].
  ///
  /// Does nothing — and does not notify listeners or attempt to persist —
  /// if [preference] equals the current value, or if this instance has
  /// already been [dispose]d. Otherwise updates in-memory state and
  /// notifies listeners immediately, then asynchronously persists the new
  /// value to [_store] (if one was supplied), queued after any still-in-
  /// -flight write from an earlier call; a persistence failure is recorded
  /// on [debugLastPersistError] but never reverts the already applied
  /// in-memory selection.
  void setThemePreference(AppThemePreference preference) {
    if (_disposed || _themePreference == preference) return;
    _themePreference = preference;
    notifyListeners();
    unawaited(_enqueuePersist(preference));
  }

  Future<void> _enqueuePersist(AppThemePreference preference) {
    final result = _persistTail.then((_) => _persist(preference));
    _persistTail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _persist(AppThemePreference preference) async {
    final store = _store;
    if (store == null) return;
    try {
      await store.setString(
        StorageKeys.themePreference,
        preference._storageValue,
      );
      _lastPersistError = null;
    } catch (error) {
      _lastPersistError = error;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
