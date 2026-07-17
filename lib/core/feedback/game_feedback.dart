/// Reports explicit gameplay outcomes — never rendered UI state — so a
/// listener (typically [AudioFeedbackCoordinator]) can trigger audio/haptic
/// feedback for each one exactly once.
///
/// `GameController` is the only thing that calls this: since it owns every
/// state transition (accepted/rejected guesses, revealed hints, win/loss)
/// as the single source of truth, it is the only place that can call each
/// method exactly once per real transition, never on a widget rebuild and
/// never inferred after the fact from rendered state. Kept free of any
/// audio/haptic-specific naming or parameters — a caller reports what
/// happened in gameplay terms only, and never needs to know (or import)
/// anything about how, or whether, that gets turned into sound or
/// vibration.
///
/// Deliberately not feature-specific to `game` in its own home, even though
/// only `GameController` implements a caller of it today: it is a shared,
/// no-Flutter-knowledge seam a cross-cutting coordinator can depend on
/// without depending on the `game` feature.
abstract class GameFeedback {
  /// A submitted guess was accepted and the game remains in progress.
  void onValidGuess();

  /// A submitted guess was rejected (blank, wrong length, non-alphabetic,
  /// not a recognized word, or the game had already ended).
  void onInvalidGuess();

  /// A hint was successfully revealed. [paid] is `true` only once its coin
  /// cost was actually deducted — never for a free hint, a cancelled paid
  /// hint, or a hint request that failed for any reason.
  void onHintRevealed({required bool paid});

  /// The game just transitioned from in-progress to won. Called exactly
  /// once per game.
  void onGameWon();

  /// The game just transitioned from in-progress to lost. Called exactly
  /// once per game.
  void onGameLost();
}

/// A [GameFeedback] that does nothing. The default for any caller (e.g.
/// `GameController`, and every existing test that constructs one) that
/// doesn't care about audio/haptic feedback.
class NoOpGameFeedback implements GameFeedback {
  const NoOpGameFeedback();

  @override
  void onValidGuess() {}

  @override
  void onInvalidGuess() {}

  @override
  void onHintRevealed({required bool paid}) {}

  @override
  void onGameWon() {}

  @override
  void onGameLost() {}
}
