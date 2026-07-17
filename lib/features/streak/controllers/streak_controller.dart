import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/time/local_date_provider.dart';
import '../data/streak_repository.dart';
import '../models/streak_state.dart';
import '../models/streak_update_result.dart';
import '../services/streak_service.dart';

/// App-wide, in-memory daily-play-streak state shared by the whole
/// `MaterialApp`.
///
/// Extends [ChangeNotifier] — the same pattern `CoinWallet`/`AppSettings`
/// use for shared, observable state per this project's state-management
/// guidance (see CLAUDE.md). [CowBullApp] owns one instance for the app's
/// lifetime and disposes it; the app-level composition root calls
/// [recordQualifyingCompletion] exactly once per completed game (normal or
/// Daily Challenge, won or lost) — never for an abandoned/restarted game,
/// since those never reach the `GameController.onGameCompleted` hook this is
/// wired to.
///
/// Every accepted update is applied to in-memory state and notifies
/// listeners immediately — synchronously, before any `await` — then
/// asynchronously persists to [_repository]; a persistence failure never
/// reverts the already-applied in-memory update, exactly like `CoinWallet`.
/// Persistence writes are serialized (see [_enqueuePersist]) so a rapid
/// sequence of updates always finishes persisted as the latest state, never
/// reordered by however long an individual write happens to take.
class StreakController extends ChangeNotifier {
  StreakController({
    required LocalDateProvider clock,
    StreakState? initialState,
    StreakRepository? repository,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _repository = repository, // ignore: prefer_initializing_formals
       _state = initialState ?? StreakState.empty();

  /// Loads the persisted streak state from [repository] (already
  /// safely-recovered from any malformed data — see
  /// `LocalStreakRepository.loadState`) and returns a [StreakController]
  /// seeded with it that persists future updates back to the same
  /// [repository].
  static Future<StreakController> load({
    required StreakRepository repository,
    required LocalDateProvider clock,
  }) async {
    final state = await repository.loadState();
    return StreakController(
      clock: clock,
      initialState: state,
      repository: repository,
    );
  }

  final LocalDateProvider _clock;
  final StreakRepository? _repository;
  static const StreakService _service = StreakService();

  StreakState _state;
  bool _disposed = false;

  /// The current streak state.
  StreakState get state => _state;

  /// The error thrown by the most recent persistence attempt, or `null` if
  /// none has failed. Exposed only so tests can assert a write was actually
  /// attempted and failed; a failed persistence write is non-fatal — the
  /// in-memory state keeps applying regardless, mirroring `CoinWallet`.
  @visibleForTesting
  Object? get debugLastPersistError => _lastPersistError;
  Object? _lastPersistError;

  Future<void> _persistTail = Future<void>.value();

  /// Records a qualifying game completion for "today" (per [_clock]).
  ///
  /// Applies `StreakService.recordQualifyingDay` against the current
  /// [state]; if the result is [StreakAlreadyCounted] (today's qualifying
  /// day was already recorded — whether by an earlier normal game or an
  /// earlier Daily Challenge completion), [state] is left unchanged and
  /// nothing is persisted. Otherwise [state] is updated and listeners are
  /// notified synchronously, then the new state is persisted in the
  /// background; a persistence failure never reverts the already-applied
  /// in-memory update.
  ///
  /// Returns the full [StreakUpdateResult] so callers (the app-level
  /// composition root) can decide what — if anything — to show the player,
  /// and can distinguish "just extended/started" from "already counted
  /// today" to avoid re-triggering streak feedback for the latter.
  StreakUpdateResult recordQualifyingCompletion() {
    final today = _clock.today();
    final result = _service.recordQualifyingDay(previous: _state, today: today);
    if (result is StreakAlreadyCounted || _disposed) return result;

    _state = result.state;
    notifyListeners();
    unawaited(_enqueuePersist(_state));
    return result;
  }

  Future<void> _enqueuePersist(StreakState state) {
    final result = _persistTail.then((_) => _persist(state));
    _persistTail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _persist(StreakState state) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.saveState(state);
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
