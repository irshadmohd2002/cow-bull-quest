import '../../../models/difficulty_selection.dart';
import 'completed_game.dart';
import 'game_outcome_breakdown.dart';

/// The maximum number of completed games kept in
/// [StatisticsSnapshot.recentGames].
///
/// Older completed games remain fully reflected in the aggregate totals
/// ([StatisticsSnapshot.wins], [StatisticsSnapshot.losses], both streaks,
/// and the by-word-length/by-difficulty breakdowns) even after they age out
/// of this bounded list — only the detailed recent-games list is truncated.
const int maxRecentGames = 20;

/// An immutable, point-in-time view of aggregate completed-game statistics.
///
/// Every derived value ([totalGames], [winRate], [averageAttemptsOnWins],
/// and each [GameOutcomeBreakdown.winRate]) is computed from stored counters
/// rather than stored redundantly, so it can never be `NaN` or drift out of
/// sync: [totalGames] is always `wins + losses`, [winRate] is `0` (never a
/// divide-by-zero) when there are no games yet, and
/// [averageAttemptsOnWins] is `null` (never a divide-by-zero) when there are
/// no wins yet.
class StatisticsSnapshot {
  /// Throws [ArgumentError] if any counter is negative, if
  /// [currentWinStreak] exceeds [bestWinStreak], if [hintFreeWins] exceeds
  /// [wins], or if [recentGames] has more than [maxRecentGames] entries.
  StatisticsSnapshot({
    required this.wins,
    required this.losses,
    required this.currentWinStreak,
    required this.bestWinStreak,
    required this.totalAttemptsOnWins,
    this.fewestAttemptsOnWins,
    this.totalHintsUsed = 0,
    this.hintFreeWins = 0,
    required Map<int, GameOutcomeBreakdown> byWordLength,
    required Map<DifficultyOption, GameOutcomeBreakdown> byDifficulty,
    required List<CompletedGame> recentGames,
  }) : byWordLength = Map.unmodifiable(byWordLength),
       byDifficulty = Map.unmodifiable(byDifficulty),
       recentGames = List.unmodifiable(recentGames) {
    if (wins < 0) {
      throw ArgumentError.value(wins, 'wins', 'must not be negative');
    }
    if (losses < 0) {
      throw ArgumentError.value(losses, 'losses', 'must not be negative');
    }
    if (currentWinStreak < 0) {
      throw ArgumentError.value(
        currentWinStreak,
        'currentWinStreak',
        'must not be negative',
      );
    }
    if (bestWinStreak < 0) {
      throw ArgumentError.value(
        bestWinStreak,
        'bestWinStreak',
        'must not be negative',
      );
    }
    if (currentWinStreak > bestWinStreak) {
      throw ArgumentError.value(
        currentWinStreak,
        'currentWinStreak',
        'must not exceed bestWinStreak ($bestWinStreak)',
      );
    }
    if (totalAttemptsOnWins < 0) {
      throw ArgumentError.value(
        totalAttemptsOnWins,
        'totalAttemptsOnWins',
        'must not be negative',
      );
    }
    final fewestAttemptsOnWins = this.fewestAttemptsOnWins;
    if (fewestAttemptsOnWins != null && fewestAttemptsOnWins < 1) {
      throw ArgumentError.value(
        fewestAttemptsOnWins,
        'fewestAttemptsOnWins',
        'must be >= 1 when not null',
      );
    }
    if (totalHintsUsed < 0) {
      throw ArgumentError.value(
        totalHintsUsed,
        'totalHintsUsed',
        'must not be negative',
      );
    }
    if (hintFreeWins < 0) {
      throw ArgumentError.value(
        hintFreeWins,
        'hintFreeWins',
        'must not be negative',
      );
    }
    if (hintFreeWins > wins) {
      throw ArgumentError.value(
        hintFreeWins,
        'hintFreeWins',
        'must not exceed wins ($wins)',
      );
    }
    if (recentGames.length > maxRecentGames) {
      throw ArgumentError.value(
        recentGames.length,
        'recentGames',
        'must not exceed $maxRecentGames entries',
      );
    }
  }

  /// A snapshot with no completed games recorded yet.
  factory StatisticsSnapshot.empty() => StatisticsSnapshot(
    wins: 0,
    losses: 0,
    currentWinStreak: 0,
    bestWinStreak: 0,
    totalAttemptsOnWins: 0,
    byWordLength: const {},
    byDifficulty: const {},
    recentGames: const [],
  );

  /// The number of completed games that were won.
  final int wins;

  /// The number of completed games that were lost.
  final int losses;

  /// The total number of completed games. Derived as `wins + losses`.
  int get totalGames => wins + losses;

  /// The win rate across all completed games, in `[0, 1]`. `0` (never
  /// `NaN`) when [totalGames] is `0`.
  double get winRate => totalGames == 0 ? 0 : wins / totalGames;

  /// The number of consecutive wins ending with the most recently completed
  /// game. `0` if the most recent game was a loss, or none has been played.
  final int currentWinStreak;

  /// The longest [currentWinStreak] ever reached.
  final int bestWinStreak;

  /// The sum of [CompletedGame.attemptsUsed] across every won game. Stored
  /// (rather than the average itself) so [averageAttemptsOnWins] can be
  /// derived without redundantly persisting a value that would drift.
  final int totalAttemptsOnWins;

  /// The mean [CompletedGame.attemptsUsed] across every won game. `null`
  /// (never a divide-by-zero) when [wins] is `0`.
  double? get averageAttemptsOnWins =>
      wins == 0 ? null : totalAttemptsOnWins / wins;

  /// The fewest [CompletedGame.attemptsUsed] across every won game — the
  /// player's personal-best attempt count. `null` when [wins] is `0`.
  ///
  /// For a wallet migrated from a pre-Milestone-19 statistics document (see
  /// `LocalStatisticsRepository`), this is a best-effort value derived only
  /// from whichever won games still happened to be in the bounded
  /// `recentGames` window at migration time — a win outside that window may
  /// have used fewer attempts, so this can only ever be as good as, or
  /// better than, what migration could see; it always becomes exact for any
  /// win recorded from that point on.
  final int? fewestAttemptsOnWins;

  /// The sum of [CompletedGame.hintsUsed] across every completed game whose
  /// hint usage is actually known (i.e. `hintsUsed != null`). A game with
  /// unknown hint usage (a pre-Milestone-19 record) contributes `0` here —
  /// not because it used no hints, but because there is nothing to add.
  /// Defaults to `0` for a document migrated from before Milestone 19,
  /// since no historical game in it has known hint usage yet.
  final int totalHintsUsed;

  /// The number of won games with *known*, exactly-zero hint usage
  /// (`hintsUsed == 0`) — never incremented for a win with unknown hint
  /// usage (`hintsUsed == null`), even though both "used no hints" and
  /// "hint usage unknown" might look superficially similar. Conflating them
  /// would misreport an old win of unknown hint usage as a genuine no-hint
  /// win. Defaults to `0` for a document migrated from before Milestone 19.
  final int hintFreeWins;

  /// Totals and wins keyed by secret-word length. Unmodifiable.
  final Map<int, GameOutcomeBreakdown> byWordLength;

  /// Totals and wins keyed by difficulty. Unmodifiable.
  final Map<DifficultyOption, GameOutcomeBreakdown> byDifficulty;

  /// The most recent completed games, newest-first, bounded to at most
  /// [maxRecentGames] entries. Unmodifiable.
  final List<CompletedGame> recentGames;
}
