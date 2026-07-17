import 'dart:async';

import 'package:flutter/foundation.dart';

import 'core/persistence/preferences_store.dart';
import 'core/persistence/storage_keys.dart';

bool? _parseStoredBool(String? value) => switch (value) {
  'true' => true,
  'false' => false,
  _ => null,
};

String _boolStorageValue(bool value) => value ? 'true' : 'false';

/// App-wide, in-memory sound-effects/music/haptics preferences shared by the
/// whole `MaterialApp`.
///
/// Extends [ChangeNotifier] — the same pattern `AppSettings` and
/// `CoinWallet` use for shared, observable state per this project's
/// state-management guidance (see CLAUDE.md). [CowBullApp] owns one
/// instance for the app's lifetime and disposes it.
///
/// The three preferences are independent: toggling one never changes either
/// of the other two, and each persists under its own [StorageKeys] entry so
/// a storage failure on one write can never corrupt another. Defaults —
/// applied whenever a key has never been written, covering both a genuine
/// first-time install and an existing install upgrading from a version that
/// predates this preference — are sound effects **on**, background music
/// **off** (so an upgrading player is never surprised by new audio it never
/// opted into), and haptics **on**.
///
/// If a [PreferencesStore] is supplied, every accepted setter call is
/// persisted to it after updating in-memory state and notifying listeners;
/// a persistence failure never reverts the in-memory selection — the
/// preference the player just picked keeps applying for the rest of this
/// session regardless of whether the write succeeds. When [store] is
/// omitted, changes remain in-memory only.
///
/// Persistence writes are serialized (see [_enqueuePersist]): each begins
/// only after the previous one has settled, so a rapid sequence of toggles
/// — even across different preferences — always finishes persisted as the
/// last value each one was set to, never reordered by however long an
/// individual write happens to take.
class AudioFeedbackSettings extends ChangeNotifier {
  AudioFeedbackSettings({
    bool initialSoundEffectsEnabled = true,
    bool initialMusicEnabled = false,
    bool initialHapticsEnabled = true,
    PreferencesStore? store,
  }) : _soundEffectsEnabled = initialSoundEffectsEnabled,
       _musicEnabled = initialMusicEnabled,
       _hapticsEnabled = initialHapticsEnabled,
       _store = store; // ignore: prefer_initializing_formals

  /// Loads every persisted preference from [store] independently — falling
  /// back to that preference's own default if nothing is stored, the stored
  /// value is unrecognized, or reading it fails — and returns an
  /// [AudioFeedbackSettings] seeded with the results that persists future
  /// changes back to the same [store].
  ///
  /// One preference's read failure never affects another's: each of the
  /// three is read in its own `try`/`catch`, so (for example) a corrupted
  /// music value still leaves a genuinely-stored sound-effects value intact.
  static Future<AudioFeedbackSettings> load(PreferencesStore store) async {
    var soundEffects = true;
    try {
      soundEffects =
          _parseStoredBool(
            await store.getString(StorageKeys.soundEffectsEnabled),
          ) ??
          true;
    } on PreferencesStoreException {
      soundEffects = true;
    }

    var music = false;
    try {
      music =
          _parseStoredBool(await store.getString(StorageKeys.musicEnabled)) ??
          false;
    } on PreferencesStoreException {
      music = false;
    }

    var haptics = true;
    try {
      haptics =
          _parseStoredBool(await store.getString(StorageKeys.hapticsEnabled)) ??
          true;
    } on PreferencesStoreException {
      haptics = true;
    }

    return AudioFeedbackSettings(
      initialSoundEffectsEnabled: soundEffects,
      initialMusicEnabled: music,
      initialHapticsEnabled: haptics,
      store: store,
    );
  }

  final PreferencesStore? _store;
  bool _soundEffectsEnabled;
  bool _musicEnabled;
  bool _hapticsEnabled;
  bool _disposed = false;

  /// Whether interface/gameplay sound effects should play.
  bool get soundEffectsEnabled => _soundEffectsEnabled;

  /// Whether the background-music loop should play.
  bool get musicEnabled => _musicEnabled;

  /// Whether device haptic feedback should trigger for app-triggered
  /// actions.
  bool get hapticsEnabled => _hapticsEnabled;

  /// The error thrown by the most recent persistence attempt, or `null` if
  /// none has failed. Exposed only so tests can assert a write was actually
  /// attempted and failed, rather than silently skipped; not surfaced in the
  /// UI, since a failed preference write is non-fatal.
  @visibleForTesting
  Object? get debugLastPersistError => _lastPersistError;
  Object? _lastPersistError;

  /// The tail of the persistence-write queue, shared across all three
  /// preferences. See the class-level doc.
  Future<void> _persistTail = Future<void>.value();

  /// Updates whether sound effects play. Does nothing if [enabled] equals
  /// the current value, or if this instance has already been [dispose]d.
  void setSoundEffectsEnabled(bool enabled) {
    if (_disposed || _soundEffectsEnabled == enabled) return;
    _soundEffectsEnabled = enabled;
    notifyListeners();
    unawaited(_enqueuePersist(StorageKeys.soundEffectsEnabled, enabled));
  }

  /// Updates whether background music plays. Does nothing if [enabled]
  /// equals the current value, or if this instance has already been
  /// [dispose]d.
  void setMusicEnabled(bool enabled) {
    if (_disposed || _musicEnabled == enabled) return;
    _musicEnabled = enabled;
    notifyListeners();
    unawaited(_enqueuePersist(StorageKeys.musicEnabled, enabled));
  }

  /// Updates whether haptic feedback triggers. Does nothing if [enabled]
  /// equals the current value, or if this instance has already been
  /// [dispose]d.
  void setHapticsEnabled(bool enabled) {
    if (_disposed || _hapticsEnabled == enabled) return;
    _hapticsEnabled = enabled;
    notifyListeners();
    unawaited(_enqueuePersist(StorageKeys.hapticsEnabled, enabled));
  }

  Future<void> _enqueuePersist(String key, bool value) {
    final result = _persistTail.then((_) => _persist(key, value));
    _persistTail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _persist(String key, bool value) async {
    final store = _store;
    if (store == null) return;
    try {
      await store.setString(key, _boolStorageValue(value));
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
