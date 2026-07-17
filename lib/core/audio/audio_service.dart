/// Plays this app's bundled sound effects and background-music loop.
///
/// A pure playback abstraction: it knows nothing about whether the player
/// has sound effects or music enabled, and nothing about game rules — it
/// only knows how to start, stop, pause, and resume specific bundled audio
/// assets. Gating playback on user preference is [AudioFeedbackCoordinator]'s
/// job, not this interface's. App code and features depend on this
/// interface rather than on `package:audioplayers` directly, so the
/// concrete playback package stays swappable and tests can use a fake with
/// no platform channels.
///
/// Every method must never throw or leave gameplay in a broken state on
/// failure — implementations are responsible for catching their own
/// playback errors internally.
abstract class AudioService {
  /// Plays the general button-activation sound effect.
  Future<void> playButtonTap();

  /// Plays the invalid/rejected-guess sound effect.
  Future<void> playInvalidGuess();

  /// Plays the hint-revealed sound effect.
  Future<void> playHintUsed();

  /// Plays the coin-deducted sound effect.
  Future<void> playCoinSpent();

  /// Plays the win sound effect.
  Future<void> playWin();

  /// Plays the loss sound effect.
  Future<void> playLoss();

  /// Starts the background-music loop from the beginning. Does nothing
  /// (does not restart) if the loop is already playing.
  Future<void> startMusic();

  /// Pauses the background-music loop in place, if playing.
  Future<void> pauseMusic();

  /// Resumes a paused background-music loop from where it left off.
  Future<void> resumeMusic();

  /// Stops the background-music loop entirely.
  Future<void> stopMusic();

  /// Releases every player this service owns. Call exactly once, at app
  /// shutdown; this instance must not be used again afterward.
  Future<void> dispose();
}
