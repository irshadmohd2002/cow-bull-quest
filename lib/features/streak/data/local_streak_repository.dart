import 'dart:convert';

import '../../../core/persistence/preferences_store.dart';
import '../../../core/persistence/storage_keys.dart';
import '../models/streak_state.dart';
import 'streak_repository.dart';

/// [StreakRepository] backed by a [PreferencesStore], storing one versioned
/// JSON document under [StorageKeys.streak].
///
/// [loadState] recovers safely — returning [StreakState.empty] — from every
/// failure mode a corrupted or unreadable install can produce: no stored
/// value at all (a fresh install, or an existing install from before this
/// milestone), a value that isn't valid JSON, a document with an
/// unrecognized version, a missing/wrong-typed field, an unparseable stored
/// date, or a value that fails [StreakState]'s own validation (e.g. a
/// negative streak, however that would have been written). A streak must
/// never prevent the app from starting.
class LocalStreakRepository implements StreakRepository {
  LocalStreakRepository({required PreferencesStore store})
    : _store = store; // ignore: prefer_initializing_formals

  final PreferencesStore _store;

  @override
  Future<StreakState> loadState() async {
    final String? raw;
    try {
      raw = await _store.getString(StorageKeys.streak);
    } on PreferencesStoreException {
      return StreakState.empty();
    }
    if (raw == null) return StreakState.empty();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('expected a JSON object');
      }
      return StreakState.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      // Malformed data (bad JSON, unsupported version, invalid field, or a
      // StreakState that fails its own validation) recovers to empty rather
      // than throwing — see the class-level doc.
      return StreakState.empty();
    }
  }

  @override
  Future<void> saveState(StreakState state) =>
      _store.setString(StorageKeys.streak, jsonEncode(state.toJson()));

  @override
  Future<void> clear() => _store.remove(StorageKeys.streak);
}
