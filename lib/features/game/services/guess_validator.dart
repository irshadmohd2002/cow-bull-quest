import '../models/game_status.dart';

final RegExp _alphabeticOnly = RegExp(r'^[a-zA-Z]+$');

/// Why a guess was rejected, as a typed value rather than a message string
/// so callers (and tests) can switch on the reason instead of parsing text.
enum GuessValidationFailure {
  /// The guess is empty or contains only whitespace.
  blank,

  /// The guess's length does not match the secret word's length.
  incorrectLength,

  /// The guess contains characters outside `a-z`/`A-Z`.
  nonAlphabetic,

  /// The game has already been won; no further guesses are accepted.
  gameAlreadyWon,
}

/// The outcome of validating a raw guess: either [ValidGuess], carrying the
/// normalized word ready to score, or [InvalidGuess], carrying a typed
/// [GuessValidationFailure].
///
/// Modeled as a sealed class (rather than throwing) because a failed
/// validation is an expected, common outcome — not an exceptional one —
/// and a future UI can exhaustively `switch` on the result without a
/// try/catch.
sealed class GuessValidation {
  const GuessValidation();
}

/// The guess passed all checks; [normalizedGuess] is lowercase and ready
/// to be scored.
final class ValidGuess extends GuessValidation {
  const ValidGuess(this.normalizedGuess);

  final String normalizedGuess;
}

/// The guess failed validation for [reason].
final class InvalidGuess extends GuessValidation {
  const InvalidGuess(this.reason);

  final GuessValidationFailure reason;
}

/// Validates a raw guess string before it is scored.
///
/// Checks run in a fixed order — already-won, then blank, then length,
/// then character set — so exactly one [GuessValidationFailure] reason is
/// ever reported per call.
class GuessValidator {
  const GuessValidator();

  /// Validates [rawGuess] against the length of the secret word and the
  /// current [status] of the game.
  GuessValidation validate({
    required String rawGuess,
    required int secretWordLength,
    required GameStatus status,
  }) {
    if (status == GameStatus.won) {
      return const InvalidGuess(GuessValidationFailure.gameAlreadyWon);
    }
    if (rawGuess.trim().isEmpty) {
      return const InvalidGuess(GuessValidationFailure.blank);
    }
    if (rawGuess.length != secretWordLength) {
      return const InvalidGuess(GuessValidationFailure.incorrectLength);
    }
    if (!_alphabeticOnly.hasMatch(rawGuess)) {
      return const InvalidGuess(GuessValidationFailure.nonAlphabetic);
    }
    return ValidGuess(rawGuess.toLowerCase());
  }
}
