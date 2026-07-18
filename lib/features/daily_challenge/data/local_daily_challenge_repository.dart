import 'dart:convert';

import '../../../core/persistence/preferences_store.dart';
import '../../../core/persistence/storage_keys.dart';
import '../../../core/time/local_date.dart';
import '../models/daily_challenge_result.dart';
import 'daily_challenge_repository.dart';

/// The document version this implementation writes/reads. Anything else is
/// treated as malformed (see [_decode]) rather than guessed at.
const int _currentDocumentVersion = 1;

/// [DailyChallengeRepository] backed by a [PreferencesStore], storing one
/// versioned JSON document — a map of ISO date string to official result —
/// under [StorageKeys.dailyChallengeResults].
///
/// Every public operation is funneled through [_enqueue] so
/// `loadResult`/`recordIfFirst`/`clear` calls on this instance always run
/// one at a time, in invocation order — the same pattern
/// `LocalStatisticsRepository` uses — so two near-simultaneous
/// `recordIfFirst` calls for the same date (e.g. a genuine completion racing
/// a rapid-restart replay's own completion) can never both "win" and
/// silently overwrite each other; the second always observes the first's
/// already-recorded result and is a true no-op.
class LocalDailyChallengeRepository implements DailyChallengeRepository {
  LocalDailyChallengeRepository({required PreferencesStore store})
    : _store = store; // ignore: prefer_initializing_formals

  final PreferencesStore _store;

  Future<void> _tail = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<DailyChallengeResult?> loadResult(LocalDate date) =>
      _enqueue(() async => (await _loadAll())[date.toIso8601String()]);

  @override
  Future<List<DailyChallengeResult>> loadAllResults() =>
      _enqueue(() async => (await _loadAll()).values.toList());

  @override
  Future<DailyChallengeResult> recordIfFirst(DailyChallengeResult result) =>
      _enqueue(() async {
        final all = await _loadAll();
        final key = result.date.toIso8601String();
        final existing = all[key];
        if (existing != null) return existing;
        all[key] = result;
        await _save(all);
        return result;
      });

  @override
  Future<void> clear() =>
      _enqueue(() => _store.remove(StorageKeys.dailyChallengeResults));

  Future<Map<String, DailyChallengeResult>> _loadAll() async {
    final raw = await _store.getString(StorageKeys.dailyChallengeResults);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final doc = decoded.cast<String, Object?>();
      if (doc['version'] != _currentDocumentVersion) return {};
      final rawResults = doc['results'];
      if (rawResults is! Map) return {};
      final results = <String, DailyChallengeResult>{};
      for (final entry in rawResults.entries) {
        try {
          results[entry.key as String] = DailyChallengeResult.fromJson(
            (entry.value as Map).cast<String, Object?>(),
          );
        } catch (_) {
          // One malformed entry never invalidates every other, otherwise-
          // valid stored result — it is simply dropped.
        }
      }
      return results;
    } catch (_) {
      // Malformed data at the top level (bad JSON, wrong shape) recovers to
      // an empty history rather than throwing — a corrupted Daily Challenge
      // history must never prevent a new challenge from being played.
      return {};
    }
  }

  Future<void> _save(Map<String, DailyChallengeResult> all) async {
    final doc = {
      'version': _currentDocumentVersion,
      'results': {
        for (final entry in all.entries) entry.key: entry.value.toJson(),
      },
    };
    await _store.setString(StorageKeys.dailyChallengeResults, jsonEncode(doc));
  }
}
