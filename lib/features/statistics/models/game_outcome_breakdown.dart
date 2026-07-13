/// Immutable win/total totals for one category (a word length or a
/// difficulty) within a statistics snapshot.
///
/// [losses] and [winRate] are derived, not stored, so they can never drift
/// out of sync with [totalGames]/[wins].
class GameOutcomeBreakdown {
  /// Throws [ArgumentError] if [totalGames] or [wins] is negative, or if
  /// [wins] exceeds [totalGames].
  GameOutcomeBreakdown({required this.totalGames, required this.wins}) {
    if (totalGames < 0) {
      throw ArgumentError.value(
        totalGames,
        'totalGames',
        'must not be negative',
      );
    }
    if (wins < 0) {
      throw ArgumentError.value(wins, 'wins', 'must not be negative');
    }
    if (wins > totalGames) {
      throw ArgumentError.value(wins, 'wins', 'must not exceed totalGames');
    }
  }

  /// A breakdown with no games recorded yet.
  static final GameOutcomeBreakdown empty = GameOutcomeBreakdown(
    totalGames: 0,
    wins: 0,
  );

  /// The number of completed games in this category.
  final int totalGames;

  /// The number of those games that were won.
  final int wins;

  /// The number of those games that were lost. Derived as
  /// `totalGames - wins`.
  int get losses => totalGames - wins;

  /// The win rate in this category, in `[0, 1]`. `0` (never `NaN`) when
  /// [totalGames] is `0`.
  double get winRate => totalGames == 0 ? 0 : wins / totalGames;

  /// Serializes this breakdown to a JSON-compatible map.
  Map<String, Object?> toJson() => {'totalGames': totalGames, 'wins': wins};

  /// Rebuilds a [GameOutcomeBreakdown] from a JSON-compatible [json] map.
  ///
  /// Throws [FormatException] if a required field is missing or the wrong
  /// type. Throws [ArgumentError] if the reconstructed values fail the same
  /// validation the default constructor enforces.
  factory GameOutcomeBreakdown.fromJson(Map<String, Object?> json) {
    final totalGames = json['totalGames'];
    final wins = json['wins'];
    if (totalGames is! int) {
      throw const FormatException(
        'game outcome breakdown "totalGames" must be an int',
      );
    }
    if (wins is! int) {
      throw const FormatException(
        'game outcome breakdown "wins" must be an int',
      );
    }
    return GameOutcomeBreakdown(totalGames: totalGames, wins: wins);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameOutcomeBreakdown &&
          other.totalGames == totalGames &&
          other.wins == wins);

  @override
  int get hashCode => Object.hash(totalGames, wins);

  @override
  String toString() =>
      'GameOutcomeBreakdown(totalGames: $totalGames, wins: $wins)';
}
