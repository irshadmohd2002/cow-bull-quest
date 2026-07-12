/// The lifecycle of a single [GameSession].
///
/// Only `inProgress` and `won` exist for this milestone: the game rules
/// define a win condition (all bulls) but no loss condition (no turn limit
/// or attempt cap), so a speculative `lost`/`notStarted` status would be
/// unused. Add further statuses only once a rule actually requires them.
enum GameStatus {
  /// The game has started and has not yet been won.
  inProgress,

  /// The most recent guess scored all bulls; no further guesses are accepted.
  won,
}
