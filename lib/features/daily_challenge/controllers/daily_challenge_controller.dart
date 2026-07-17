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
/// use for shared, observable state. Tracks only *today's* official result
/// (per [_clock]) — there is no requirement in this milestone to browse past
/// Daily Challenge history, so this deliberately does not cache more than
/// that. [today] and [officialResultToday] are refreshed from
/// [_repository] by [refresh]; the app-level composition root calls it once
/// at startup (via [load]) and again each time the player returns to Home,
/// so a long-lived session that happens to cross midnight still shows the
/// correct date/status rather than a stale cached one.
class DailyChallengeController extends ChangeNotifier {
  /// Builds a controller directly from already-known state. [today] defaults
  /// to `clock.today()`, and [initialResult] defaults to `null` (not yet
  /// played) — the same "non-persistent, in-memory-only fallback when no
  /// repository is supplied" pattern `CoinWallet`/`StreakController` use, so
  /// [repository] is optional: when omitted, [refresh] still updates
  /// [today] (clearing [officialResultToday], since there is nothing to
  /// reload it from) but [recordIfFirst] never persists anything.
  DailyChallengeController({
    required LocalDateProvider clock,
    DailyChallengeRepository? repository,
    LocalDate? today,
    DailyChallengeResult? initialResult,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock, // ignore: prefer_initializing_formals
       _today = today ?? clock.today(),
       _officialResultToday =
           initialResult; // ignore: prefer_initializing_formals

  /// Loads today's official result (if any) from [repository] and returns a
  /// [DailyChallengeController] seeded with it.
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
    return DailyChallengeController(
      repository: repository,
      clock: clock,
      today: today,
      initialResult: result,
    );
  }

  final DailyChallengeRepository? _repository;
  final LocalDateProvider _clock;
  bool _disposed = false;

  LocalDate _today;
  DailyChallengeResult? _officialResultToday;

  /// The local calendar date this controller's state currently reflects.
  /// May go stale if the app stays open across a midnight rollover without
  /// [refresh] being called again — see the class-level doc.
  LocalDate get today => _today;

  /// Today's official Daily Challenge result, or `null` if today's
  /// challenge has not been completed yet.
  DailyChallengeResult? get officialResultToday => _officialResultToday;

  /// Re-derives "today" from [_clock] and, if it has changed since this
  /// controller's state was last loaded, reloads that date's official
  /// result from [_repository]. A no-op (and never notifies) if the date is
  /// unchanged, so calling this liberally (e.g. every time Home is
  /// revisited) never causes redundant rebuilds.
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
  /// official result or be recorded a second time. Updates in-memory state
  /// and notifies listeners synchronously for a genuinely new official
  /// result, then persists it in the background; a persistence failure
  /// never reverts the already-applied in-memory result.
  DailyChallengeResult recordIfFirst(DailyChallengeResult candidate) {
    assert(
      candidate.date == _today,
      'recordIfFirst candidate date (${candidate.date}) must match today '
      '($_today)',
    );
    final existing = _officialResultToday;
    if (existing != null) return existing;

    _officialResultToday = candidate;
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
