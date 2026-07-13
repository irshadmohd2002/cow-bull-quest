import 'package:flutter/foundation.dart';

import '../data/statistics_repository.dart';
import '../models/completed_game.dart';
import '../models/statistics_snapshot.dart';
import 'statistics_controller_state.dart';

/// Coordinates a [StatisticsRepository] into the UI-ready
/// [StatisticsControllerState] the statistics screen (and the app-level
/// completion-recording hook) can listen to.
///
/// Extends [ChangeNotifier] — the same pattern `GameController` uses for
/// shared, observable state per this project's state-management guidance
/// (see CLAUDE.md). Never computes statistics itself: every aggregate is
/// already computed by the [StatisticsRepository]/[StatisticsSnapshot] it
/// wraps, so this class stays orchestration-only.
class StatisticsController extends ChangeNotifier {
  StatisticsController({required StatisticsRepository repository})
    : _repository = repository; // ignore: prefer_initializing_formals

  final StatisticsRepository _repository;

  StatisticsControllerState _state = const StatisticsLoading();

  /// The controller's current lifecycle state.
  StatisticsControllerState get state => _state;

  int _generation = 0;
  bool _disposed = false;

  /// Loads the current statistics snapshot.
  ///
  /// Emits [StatisticsLoading] immediately, then either [StatisticsReady] on
  /// success or [StatisticsFailure] (carrying the previous snapshot, if any)
  /// on failure. If another call to [load], [recordCompletedGame], or
  /// [clear] is made before this one completes, this call's result is
  /// discarded — a generation counter, bumped on every call (and on
  /// [dispose]), lets each call recognize when it has been superseded so a
  /// slow, stale request can never overwrite newer state.
  Future<void> load() => _run(_repository.loadSnapshot);

  /// Records [game] and refreshes the snapshot from the result.
  ///
  /// Same stale-result and disposal guarantees as [load]. Duplicate
  /// completed-game IDs are guarded against by the repository, not here.
  Future<void> recordCompletedGame(CompletedGame game) =>
      _run(() => _repository.recordCompletedGame(game));

  /// Permanently clears all recorded statistics.
  ///
  /// Same stale-result and disposal guarantees as [load].
  Future<void> clear() => _run(_repository.clearStatistics);

  Future<void> _run(Future<StatisticsSnapshot> Function() operation) async {
    if (_disposed) return;
    final generation = ++_generation;
    // Captured before switching to StatisticsLoading below, which would
    // otherwise erase the only record of the previous snapshot before a
    // failure gets a chance to carry it forward.
    final previousSnapshot = _lastKnownSnapshot;
    _setState(const StatisticsLoading());
    try {
      final snapshot = await operation();
      if (_disposed || generation != _generation) return;
      _setState(StatisticsReady(snapshot));
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _setState(
        StatisticsFailure(lastSnapshot: previousSnapshot, error: error),
      );
    }
  }

  StatisticsSnapshot? get _lastKnownSnapshot => switch (_state) {
    StatisticsReady(:final snapshot) => snapshot,
    StatisticsFailure(:final lastSnapshot) => lastSnapshot,
    StatisticsLoading() => null,
  };

  void _setState(StatisticsControllerState newState) {
    if (_disposed || identical(_state, newState)) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
