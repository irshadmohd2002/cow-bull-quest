import '../models/game_session.dart';
import '../models/game_status.dart';
import '../models/guess.dart';
import 'guess_scorer.dart';
import 'guess_validator.dart';

/// The outcome of submitting a guess: either [GuessAccepted], carrying the
/// updated session and the recorded [Guess], or [GuessRejected], carrying
/// the typed reason the guess did not change the session.
///
/// Modeled as a sealed class rather than a thrown exception for the same
/// reason as [GuessValidation]: an invalid guess is routine input from a
/// player, not an exceptional program state, so callers should be able to
/// exhaustively `switch` on the outcome instead of using try/catch.
sealed class GuessSubmission {
  const GuessSubmission();
}

/// The guess was valid; [session] is the new, updated session and [guess]
/// is the entry that was appended to its history.
final class GuessAccepted extends GuessSubmission {
  const GuessAccepted({required this.session, required this.guess});

  final GameSession session;
  final Guess guess;
}

/// The guess was rejected for [reason] and the session was left unchanged.
final class GuessRejected extends GuessSubmission {
  const GuessRejected(this.reason);

  final GuessValidationFailure reason;
}

/// Orchestrates a game of Bulls and Cows: starting a session, and
/// validating, scoring, and recording guesses against it.
///
/// Stateless and functional by design — it takes the current [GameSession]
/// as input and returns a new one rather than holding session state
/// itself. This keeps it trivially testable, mirrors the immutability of
/// [GameSession] and [GuessResult], and fits a future presentation layer
/// that holds the session in a `ChangeNotifier` and calls this engine to
/// compute the next state, per this project's state-management approach.
class GameEngine {
  const GameEngine({
    this.scorer = const GuessScorer(),
    this.validator = const GuessValidator(),
  });

  final GuessScorer scorer;
  final GuessValidator validator;

  /// Starts a new, in-progress session for [secretWord].
  GameSession startGame({required String secretWord}) =>
      GameSession.start(secretWord);

  /// Validates, scores, and (if valid) records [rawGuess] against
  /// [session].
  ///
  /// Returns [GuessRejected] without modifying [session] if the guess is
  /// blank, the wrong length, contains non-alphabetic characters, or the
  /// game has already been won. Otherwise returns [GuessAccepted] with a
  /// new session whose history includes the scored guess, and whose
  /// status becomes [GameStatus.won] if the guess scored all bulls.
  GuessSubmission submitGuess({
    required GameSession session,
    required String rawGuess,
  }) {
    final validation = validator.validate(
      rawGuess: rawGuess,
      secretWordLength: session.secretWord.length,
      status: session.status,
    );
    if (validation is InvalidGuess) {
      return GuessRejected(validation.reason);
    }

    final normalizedGuess = (validation as ValidGuess).normalizedGuess;
    final result = scorer.score(
      secretWord: session.secretWord,
      guess: normalizedGuess,
    );
    final guess = Guess(
      word: normalizedGuess,
      result: result,
      turnNumber: session.guesses.length + 1,
    );
    final hasWon = result.bulls == session.secretWord.length;

    final updatedSession = session.copyWith(
      guesses: [...session.guesses, guess],
      status: hasWon ? GameStatus.won : session.status,
    );

    return GuessAccepted(session: updatedSession, guess: guess);
  }
}
