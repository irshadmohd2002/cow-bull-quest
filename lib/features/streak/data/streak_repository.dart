import '../models/streak_state.dart';

/// Local persistence for the daily-play streak.
///
/// Implementations must never let malformed stored data (a corrupted
/// document, an invalid negative streak, an unparseable date) propagate as
/// an exception from [loadState] — see `LocalStreakRepository` — since a
/// corrupted streak must never prevent the app from starting or a game from
/// completing. [saveState] may throw; callers are responsible for treating a
/// persistence failure as non-fatal, exactly like `CoinWallet`/`AppSettings`
/// already do for their own writes.
abstract class StreakRepository {
  /// Loads the current streak state, or [StreakState.empty] if nothing has
  /// been recorded yet (including a fresh install, and safe recovery from
  /// malformed stored data).
  Future<StreakState> loadState();

  /// Persists [state], overwriting whatever was previously stored.
  Future<void> saveState(StreakState state);

  /// Permanently deletes the stored streak state. Never touches any other
  /// persisted preference.
  Future<void> clear();
}
