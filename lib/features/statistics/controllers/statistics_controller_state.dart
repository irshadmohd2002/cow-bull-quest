import '../models/statistics_snapshot.dart';

/// The lifecycle state exposed by [StatisticsController] to presentation
/// code.
///
/// A sealed hierarchy so the statistics screen can exhaustively `switch`
/// over exactly one source of truth, instead of combining several booleans/
/// nullable fields that could disagree with each other.
sealed class StatisticsControllerState {
  const StatisticsControllerState();
}

/// Statistics are being loaded, recorded, or cleared; no result is known
/// yet. Also the controller's initial state, before its first operation.
final class StatisticsLoading extends StatisticsControllerState {
  const StatisticsLoading();
}

/// The current statistics snapshot is known and up to date.
final class StatisticsReady extends StatisticsControllerState {
  const StatisticsReady(this.snapshot);

  final StatisticsSnapshot snapshot;
}

/// The most recent operation failed. [lastSnapshot] is the last
/// successfully loaded/recorded/cleared snapshot, if any, so presentation
/// code can keep showing stale-but-known data alongside the failure
/// message rather than nothing at all.
final class StatisticsFailure extends StatisticsControllerState {
  const StatisticsFailure({required this.lastSnapshot, required this.error});

  final StatisticsSnapshot? lastSnapshot;
  final Object error;
}
