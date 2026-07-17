import 'dart:collection';

import '../models/game_config.dart';
import '../models/game_session.dart';
import '../models/game_status.dart';
import '../models/guess.dart';
import '../models/hint_state.dart';
import '../models/revealed_hint.dart';
import '../services/guess_validator.dart';

/// A presentation-safe projection of an in-progress [GameSession].
///
/// Deliberately omits [GameSession.secretWord]: this is the type
/// [GameActive] exposes while a game is running, so the active-game UI has
/// no obvious getter through which to display the answer mid-game.
/// [GameCompleted] exposes the full [GameSession] instead, once revealing
/// the secret word is the intended behavior.
class GameSessionView {
  GameSessionView._({
    required this.wordLength,
    required this.maxAttempts,
    required this.attemptsUsed,
    required this.attemptsRemaining,
    required this.status,
    required List<Guess> guesses,
  }) : _guesses = List.unmodifiable(guesses);

  /// Builds a view of [session] with the secret word stripped out.
  factory GameSessionView.fromSession(GameSession session) => GameSessionView._(
    wordLength: session.secretWord.length,
    maxAttempts: session.maxAttempts,
    attemptsUsed: session.attemptsUsed,
    attemptsRemaining: session.attemptsRemaining,
    status: session.status,
    guesses: session.guesses,
  );

  /// The secret word's length.
  final int wordLength;

  /// The maximum number of valid guesses allowed.
  final int maxAttempts;

  /// The number of valid guesses made so far.
  final int attemptsUsed;

  /// The number of valid guesses still available.
  final int attemptsRemaining;

  /// The session's current lifecycle status; authoritative for
  /// in-progress/won/lost.
  final GameStatus status;

  final List<Guess> _guesses;

  /// The guesses made so far, oldest first. Unmodifiable.
  UnmodifiableListView<Guess> get guesses => UnmodifiableListView(_guesses);
}

/// The lifecycle state exposed by [GameController] to presentation code.
///
/// A sealed hierarchy so a future UI can exhaustively `switch` over exactly
/// one lifecycle source of truth, instead of combining several booleans
/// that could disagree with each other.
sealed class GameControllerState {
  const GameControllerState();
}

/// No game has been started yet.
final class GameIdle extends GameControllerState {
  const GameIdle();
}

/// A secret word is being selected for [config]; no session exists yet.
final class GameLoading extends GameControllerState {
  const GameLoading(this.config);

  final GameConfig config;
}

/// A game is in progress. [view] never exposes the secret word; [lastRejection]
/// carries the typed reason the most recently submitted guess was rejected,
/// or `null` if the last submission was accepted (or none has been made
/// yet). [hintState] carries every hint revealed so far this game —
/// defaults to [HintState.initial] (no hints used) for callers that don't
/// care about hints.
final class GameActive extends GameControllerState {
  /// Throws [ArgumentError] unless [view].[GameSessionView.status] is
  /// [GameStatus.inProgress] — [GameActive] and [GameCompleted] are
  /// mutually exclusive views of a session's lifecycle, so a won/lost
  /// session can never be represented as "active" here.
  GameActive({
    required this.view,
    this.lastRejection,
    this.hintState = HintState.initial,
  }) {
    if (view.status != GameStatus.inProgress) {
      throw ArgumentError.value(
        view.status,
        'view.status',
        'GameActive requires a GameSessionView with status inProgress',
      );
    }
  }

  final GameSessionView view;
  final GuessValidationFailure? lastRejection;
  final HintState hintState;
}

/// The game has ended. [session] is the full, final [GameSession] — with
/// [GameSession.status] of [GameStatus.won] or [GameStatus.lost] — and its
/// [GameSession.secretWord] is deliberately reachable here, now that the
/// game is over.
final class GameCompleted extends GameControllerState {
  /// Throws [ArgumentError] unless [session].[GameSession.status] is
  /// [GameStatus.won] or [GameStatus.lost] — an in-progress session can
  /// never be represented as "completed" here.
  GameCompleted(this.session) {
    if (session.status != GameStatus.won && session.status != GameStatus.lost) {
      throw ArgumentError.value(
        session.status,
        'session.status',
        'GameCompleted requires a session with status won or lost',
      );
    }
  }

  final GameSession session;
}

/// Starting a game for [config] failed before a session could be created.
/// [error] preserves the original typed exception thrown by the word
/// repository (e.g. an [ArgumentError] for an unsupported configuration, or
/// one of the `AssetWordRepository` exceptions for an asset/content
/// failure) rather than reducing it to a message string; [stackTrace] is
/// the matching stack trace captured at the `catch` site.
final class GameStartupFailure extends GameControllerState {
  const GameStartupFailure({
    required this.config,
    required this.error,
    required this.stackTrace,
  });

  final GameConfig config;
  final Object error;
  final StackTrace stackTrace;
}

/// Hint availability and pricing for the currently active game, as returned
/// by `GameController.hintAvailability`. Recomputed fresh on every read —
/// never cached — so it always reflects the latest guesses and hints used.
class HintAvailability {
  const HintAvailability({
    required this.canRequestHint,
    required this.hintsUsed,
    required this.maxHints,
    required this.nextHintCost,
  });

  /// Whether calling `GameController.useHint` right now could reveal a
  /// hint: the game is active, this difficulty's hint limit has not been
  /// reached, and at least one letter position remains unrevealed. Does
  /// *not* account for coin balance — a caller with insufficient coins
  /// still sees `true` here (so the UI can still show the cost), and
  /// `useHint` itself is what rejects the attempt for insufficient funds.
  final bool canRequestHint;

  /// The number of hints already used this game.
  final int hintsUsed;

  /// The maximum number of hints allowed this game, for this difficulty.
  final int maxHints;

  /// The coin cost of the next hint if used right now: `0` for a free
  /// hint. Only meaningful when [canRequestHint] is `true`.
  final int nextHintCost;
}

/// Why `GameController.useHint` did not reveal a hint.
enum HintUnavailableReason {
  /// No game is currently active (idle, loading, completed, or a failed
  /// startup).
  gameNotActive,

  /// This difficulty's hint limit has already been reached this game.
  limitReached,

  /// Every letter position is already known (from a Bull or an earlier
  /// hint this game); there is nothing left a hint could usefully reveal.
  noUsefulHintRemains,

  /// A paid hint was requested but the wallet balance is below its cost.
  insufficientCoins,
}

/// The outcome of `GameController.useHint`.
sealed class HintOutcome {
  const HintOutcome();
}

/// A hint was successfully revealed. [coinsSpent] is `0` for a free hint.
final class HintRevealed extends HintOutcome {
  const HintRevealed({required this.hint, required this.coinsSpent});

  final RevealedHint hint;
  final int coinsSpent;
}

/// No hint was revealed and no coins were charged.
final class HintNotRevealed extends HintOutcome {
  const HintNotRevealed(this.reason);

  final HintUnavailableReason reason;
}
