import '../models/game_config.dart';
import '../models/game_session.dart';
import '../models/game_status.dart';
import '../models/guess.dart';
import 'guess_scorer.dart';
import 'guess_validator.dart';

/// The outcome of submitting a guess: either [GuessAccepted], carrying the
/// updated session and the recorded [Guess], or [GuessRejected], carrying
/// the original, unchanged session and the typed reason it was rejected.
///
/// Modeled as a sealed class rather than a thrown exception for the same
/// reason as [GuessValidation]: an invalid guess is routine input from a
/// player, not an exceptional program state, so callers should be able to
/// exhaustively `switch` on the outcome instead of using try/catch. Both
/// variants expose [session] so callers can read "the session after this
/// submission" uniformly, without switching first.
sealed class GuessSubmission {
  const GuessSubmission();

  /// The session after this submission: a new session if [this] is
  /// [GuessAccepted], or the exact original session, untouched, if [this]
  /// is [GuessRejected].
  GameSession get session;
}

/// The guess was valid; [session] is the new, updated session and [guess]
/// is the entry that was appended to its history.
final class GuessAccepted extends GuessSubmission {
  const GuessAccepted({required this.session, required this.guess});

  @override
  final GameSession session;
  final Guess guess;
}

/// The guess was rejected for [reason]; [session] is the exact original
/// session instance passed to [GameEngine.submitGuess], left unchanged.
final class GuessRejected extends GuessSubmission {
  const GuessRejected({required this.session, required this.reason});

  @override
  final GameSession session;
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

  /// Starts a new, in-progress session for [secretWord] using the attempt
  /// limit from [config].
  ///
  /// Throws [ArgumentError] if [secretWord]'s length does not match
  /// [config.wordLength] — this would otherwise silently produce a session
  /// whose attempt limit doesn't correspond to its own secret word.
  GameSession startGame({
    required String secretWord,
    required GameConfig config,
  }) {
    if (secretWord.length != config.wordLength) {
      throw ArgumentError.value(
        secretWord,
        'secretWord',
        'length (${secretWord.length}) does not match '
            'config.wordLength (${config.wordLength})',
      );
    }
    return GameSession.start(secretWord, maxAttempts: config.maxAttempts);
  }

  /// Validates, scores, and (if valid) records [rawGuess] against
  /// [session].
  ///
  /// Returns [GuessRejected] without modifying [session] if the guess is
  /// blank, the wrong length, contains non-alphabetic characters, or the
  /// game has already ended. Otherwise returns [GuessAccepted] with a new
  /// session whose history includes the scored guess, and whose status
  /// becomes [GameStatus.won] if the guess scored all bulls, or
  /// [GameStatus.lost] if it didn't and no attempts remain — a winning
  /// final guess always wins, never loses.
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
      return GuessRejected(session: session, reason: validation.reason);
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
    final updatedGuesses = [...session.guesses, guess];
    final hasWon = result.bulls == session.secretWord.length;
    final attemptsExhausted = updatedGuesses.length >= session.maxAttempts;

    final GameStatus newStatus;
    if (hasWon) {
      newStatus = GameStatus.won;
    } else if (attemptsExhausted) {
      newStatus = GameStatus.lost;
    } else {
      newStatus = session.status;
    }

    final updatedSession = session.copyWith(
      guesses: updatedGuesses,
      status: newStatus,
    );

    return GuessAccepted(session: updatedSession, guess: guess);
  }
}
