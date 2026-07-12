/// The lifecycle of a single [GameSession].
enum GameStatus {
  /// The game has started and has neither been won nor lost yet.
  inProgress,

  /// The most recent guess scored all bulls; no further guesses are accepted.
  won,

  /// The maximum number of valid attempts was used without scoring all
  /// bulls; no further guesses are accepted.
  lost,
}
