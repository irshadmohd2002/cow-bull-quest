import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/time/local_date.dart';
import '../../../core/time/local_date_provider.dart';
import '../data/daily_challenge_repository.dart';
import '../models/daily_challenge_result.dart';

/// App-wide, in-memory "today's Daily Challenge" state shared by the whole
/// `MaterialApp`.
///
/// Extends [ChangeNotifier] — the same pattern `CoinWallet`/`StreakController`
/// use for shared, observable state. Tracks *today's* official result (per
/// [_clock]) plus (since Milestone 19) the lifetime [completedCount]/
/// [wonCount] across every calendar date ever played — there is still no
/// requirement to browse *which* past dates were played or their individual
/// results, so this deliberately caches only those two running totals, not
/// full history. [today] and [officialResultToday] are refreshed from
/// [_repository] by [refresh]; the app-level composition root calls it once
/// at startup (via [load]) and again each time the player returns to Home,
/// so a long-lived session that happens to cross midnight still shows the
/// correct date/status rather than a stale cached one. [completedCount]/
/// [wonCount] are not date-scoped, so [refresh] never touches them — only
/// [load] (once, from full history) and [recordIfFirst] (incrementally, for
/// a genuinely new completion) ever change them.
class DailyChallengeController extends ChangeNotifier {
  /// Builds a controller directly from already-known state. [today] defaults
  /// to `clock.today()`, and [initialResult] defaults to `null` (not yet
  /// played) — the same "non-persistent, in-memory-only fallback when no
  /// repository is supplied" pattern `CoinWallet`/`StreakController` use, so
  /// [repository] is optional: when omitted, [refresh] still updates
  /// [today] (clearing [officialResultToday], since there is nothing to
  /// reload it from) but [recordIfFirst] never persists anything.
  /// [initialCompletedCount]/[initialWonCount] both default to `0`, matching
  /// that same "nothing to reload without a repository" fallback.
  DailyChallengeController({
    required LocalDateProvider clock,
    DailyChallengeRepository? repository,
    LocalDate? today,
    DailyChallengeResult? initialResult,
    int initialCompletedCount = 0,
    int initialWonCount = 0,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock, // ignore: prefer_initializing_formals
       _today = today ?? clock.today(),
       _officialResultToday = initialResult,
       _completedCount = initialCompletedCount,
       _wonCount = initialWonCount;

  /// Loads today's official result (if any) and the lifetime completed/won
  /// counts (from every recorded result, any date) from [repository], and
  /// returns a [DailyChallengeController] seeded with both.
  static Future<DailyChallengeController> load({
    required DailyChallengeRepository repository,
    required LocalDateProvider clock,
  }) async {
    final today = clock.today();
    DailyChallengeResult? result;
    try {
      result = await repository.loadResult(today);
    } catch (_) {
      // A corrupted history must never prevent the app from starting; today
      // is simply treated as not-yet-played.
      result = null;
    }
    var completedCount = 0;
    var wonCount = 0;
    try {
      final all = await repository.loadAllResults();
      completedCount = all.length;
      wonCount = all.where((result) => result.won).length;
    } catch (_) {
      // Mirrors the same recovery as loadResult above: a corrupted history
      // is treated as zero prior completions rather than blocking startup.
    }
    return DailyChallengeController(
      repository: repository,
      clock: clock,
      today: today,
      initialResult: result,
      initialCompletedCount: completedCount,
      initialWonCount: wonCount,
    );
  }

  final DailyChallengeRepository? _repository;
  final LocalDateProvider _clock;
  bool _disposed = false;

  LocalDate _today;
  DailyChallengeResult? _officialResultToday;
  int _completedCount;
  int _wonCount;

  /// The local calendar date this controller's state currently reflects.
  /// May go stale if the app stays open across a midnight rollover without
  /// [refresh] being called again — see the class-level doc.
  LocalDate get today => _today;

  /// Today's official Daily Challenge result, or `null` if today's
  /// challenge has not been completed yet.
  DailyChallengeResult? get officialResultToday => _officialResultToday;

  /// The number of calendar dates with an official Daily Challenge result —
  /// won or lost — across this installation's entire history, not just
  /// today. Never decreases.
  int get completedCount => _completedCount;

  /// The number of those official results that were won. Always
  /// `<= completedCount`.
  int get wonCount => _wonCount;

  /// Re-derives "today" from [_clock] and, if it has changed since this
  /// controller's state was last loaded, reloads that date's official
  /// result from [_repository]. A no-op (and never notifies) if the date is
  /// unchanged, so calling this liberally (e.g. every time Home is
  /// revisited) never causes redundant rebuilds. Never touches
  /// [completedCount]/[wonCount] — those are not date-scoped.
  Future<void> refresh() async {
    final today = _clock.today();
    if (today == _today) return;
    final repository = _repository;
    DailyChallengeResult? result;
    if (repository != null) {
      try {
        result = await repository.loadResult(today);
      } catch (_) {
        result = null;
      }
    }
    if (_disposed) return;
    _today = today;
    _officialResultToday = result;
    notifyListeners();
  }

  /// Records [candidate] as today's official result if none is recorded
  /// yet.
  ///
  /// [candidate].[DailyChallengeResult.date] must equal [today] — the
  /// composition root only ever builds a candidate from a Daily Challenge
  /// session that was itself started for today's date, so this is asserted
  /// rather than silently handled. If today's challenge is already
  /// recorded (a replay's completion), this is a no-op that returns the
  /// existing official result unchanged: replay can never overwrite the
  /// official result, be recorded a second time, or double-count
  /// [completedCount]/[wonCount]. Updates in-memory state (including
  /// incrementing [completedCount], and [wonCount] if [candidate] was won)
  /// and notifies listeners synchronously for a genuinely new official
  /// result, then persists it in the background; a persistence failure
  /// never reverts the already-applied in-memory result or counts.
  DailyChallengeResult recordIfFirst(DailyChallengeResult candidate) {
    assert(
      candidate.date == _today,
      'recordIfFirst candidate date (${candidate.date}) must match today '
      '($_today)',
    );
    final existing = _officialResultToday;
    if (existing != null) return existing;

    _officialResultToday = candidate;
    _completedCount++;
    if (candidate.won) _wonCount++;
    if (!_disposed) notifyListeners();
    unawaited(_persist(candidate));
    return candidate;
  }

  Future<void> _persist(DailyChallengeResult result) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.recordIfFirst(result);
    } catch (_) {
      // Non-fatal: the in-memory official result already applied above is
      // this session's source of truth regardless of whether the write
      // succeeds, mirroring CoinWallet/StreakController.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
