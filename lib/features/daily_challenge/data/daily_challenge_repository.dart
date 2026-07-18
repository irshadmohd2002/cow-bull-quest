import '../../../core/time/local_date.dart';
import '../models/daily_challenge_result.dart';

/// Local persistence for official Daily Challenge results, one per local
/// calendar date.
///
/// Implementations must never let malformed stored data propagate as an
/// exception from [loadResult] — see `LocalDailyChallengeRepository` — a
/// corrupted history must never prevent the app from starting or a Daily
/// Challenge from being played.
abstract class DailyChallengeRepository {
  /// Loads the official result for [date], or `null` if [date] has no
  /// completed Daily Challenge yet (including safe recovery from malformed
  /// stored data for that date).
  Future<DailyChallengeResult?> loadResult(LocalDate date);

  /// Loads every official result ever recorded, across every date, in no
  /// particular order. Used only to compute lifetime Daily Challenge
  /// statistics (completed/won counts) — see `DailyChallengeController`.
  /// Malformed data for one date never prevents every other, otherwise-valid
  /// date's result from being returned, mirroring [loadResult]'s own
  /// per-date recovery.
  Future<List<DailyChallengeResult>> loadAllResults();

  /// Records [result] as the official result for its date, but only if none
  /// is already stored for that date — the first completed attempt for a
  /// date is always the official one; a later call for the same date is a
  /// no-op. Returns the official result for that date: either the
  /// newly-stored [result], or whatever was already recorded.
  Future<DailyChallengeResult> recordIfFirst(DailyChallengeResult result);

  /// Permanently deletes every stored Daily Challenge result. Never touches
  /// any other persisted preference.
  Future<void> clear();
}
