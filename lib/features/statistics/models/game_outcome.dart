/// Whether a completed game was won or lost.
///
/// A completed-game record only ever represents a finished game, so this
/// carries just the two terminal outcomes — unlike the `game` feature's own
/// `GameStatus`, which also has an in-progress value that never applies to a
/// game logged for statistics.
enum GameOutcome {
  won,
  lost;

  /// The stable string this outcome is persisted as. Never the enum index,
  /// which is not stable across releases if values are reordered.
  String get storageValue => switch (this) {
    GameOutcome.won => 'won',
    GameOutcome.lost => 'lost',
  };
}

/// Parses a [GameOutcome] from its [GameOutcome.storageValue].
///
/// Throws [FormatException] if [value] is not a recognized outcome string.
GameOutcome gameOutcomeFromStorage(String value) => switch (value) {
  'won' => GameOutcome.won,
  'lost' => GameOutcome.lost,
  _ => throw FormatException('unknown game outcome value: $value'),
};
