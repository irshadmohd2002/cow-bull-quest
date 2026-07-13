import '../../../core/exceptions.dart';
import '../models/completed_game.dart';
import '../models/statistics_snapshot.dart';

/// Thrown when [StatisticsRepository] cannot load, record, or clear
/// statistics.
class StatisticsRepositoryException extends AppException {
  const StatisticsRepositoryException(super.message);
}

/// Local persistence for completed-game statistics.
///
/// Every method returns the resulting [StatisticsSnapshot] so callers always
/// see consistent, up-to-date aggregates; a failed persistence attempt
/// throws [StatisticsRepositoryException] (or lets a [PreferencesStore]'s
/// own typed exception propagate) rather than returning a snapshot that
/// implies the write succeeded. Implementations must serialize
/// [loadSnapshot]/[recordCompletedGame]/[clearStatistics] calls made on the
/// same instance so they run in invocation order — never interleaving a
/// read-modify-write cycle with another call's — so concurrent callers can
/// never lose an update or resurrect data an intervening clear removed.
abstract class StatisticsRepository {
  /// Loads the current statistics snapshot, or an empty one if nothing has
  /// been recorded yet.
  ///
  /// Throws [StatisticsRepositoryException] if the stored data is malformed
  /// or was written by an unsupported (e.g. newer) document version.
  Future<StatisticsSnapshot> loadSnapshot();

  /// Records [game] and returns the updated snapshot.
  ///
  /// If [game].id matches any game ever previously recorded — not just one
  /// still present in the bounded [StatisticsSnapshot.recentGames] — this
  /// is a no-op that returns the current snapshot unchanged: completed
  /// games are recorded at most once, for the lifetime of the stored data,
  /// not just while their record remains in the recent-games window.
  Future<StatisticsSnapshot> recordCompletedGame(CompletedGame game);

  /// Permanently deletes all recorded statistics and returns an empty
  /// snapshot. Never touches any other persisted preference (e.g. theme).
  Future<StatisticsSnapshot> clearStatistics();
}
