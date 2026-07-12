import 'dart:collection';
import 'dart:math' as math;

import 'game_status.dart';
import 'guess.dart';

final RegExp _alphabeticOnly = RegExp(r'^[a-zA-Z]+$');

/// The immutable state of one game: the secret word, the guesses made so
/// far, the maximum number of valid attempts allowed, and the current
/// [GameStatus].
///
/// The secret word is kept readable (rather than hidden behind the model)
/// because both the game engine need it to score guesses and a future
/// presentation layer will need it to reveal the answer once the game is
/// won — hiding it here would just push the same access back out through
/// another method. Keeping guesses from a player mid-game is a UI-level
/// display concern, not a constraint this domain model should enforce.
class GameSession {
  GameSession._({
    required this.secretWord,
    required List<Guess> guesses,
    required this.status,
    required this.maxAttempts,
  }) : _guesses = List.unmodifiable(guesses);

  /// Starts a new, in-progress session for [secretWord] with [maxAttempts]
  /// valid guesses allowed.
  ///
  /// [secretWord] is normalized to lowercase. Throws [ArgumentError] if it
  /// is empty or contains characters outside `a-z`/`A-Z`: an invalid secret
  /// would make the session permanently unwinnable, so this is rejected at
  /// creation rather than left to surface confusingly later. Throws
  /// [ArgumentError] if [maxAttempts] is not positive, for the same reason.
  factory GameSession.start(String secretWord, {required int maxAttempts}) {
    if (!_alphabeticOnly.hasMatch(secretWord)) {
      throw ArgumentError.value(
        secretWord,
        'secretWord',
        'must be non-empty and contain only letters a-z',
      );
    }
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be >= 1');
    }
    return GameSession._(
      secretWord: secretWord.toLowerCase(),
      guesses: const [],
      status: GameStatus.inProgress,
      maxAttempts: maxAttempts,
    );
  }

  /// The normalized (lowercase) secret word for this session.
  final String secretWord;

  final List<Guess> _guesses;

  /// The guesses made so far, oldest first. Unmodifiable: mutate history by
  /// creating a new session via [copyWith].
  UnmodifiableListView<Guess> get guesses => UnmodifiableListView(_guesses);

  /// The current lifecycle state of this session.
  final GameStatus status;

  /// The maximum number of valid guesses allowed for this session.
  final int maxAttempts;

  /// The number of valid guesses made so far. Derived from [guesses] —
  /// only accepted (valid) guesses are ever appended to history — rather
  /// than tracked as a separate counter that could drift out of sync.
  int get attemptsUsed => _guesses.length;

  /// The number of valid guesses still available. Never negative, even if
  /// [attemptsUsed] were to reach or exceed [maxAttempts].
  int get attemptsRemaining => math.max(0, maxAttempts - attemptsUsed);

  /// Returns a new session with the given fields replaced; leaves this
  /// instance untouched.
  GameSession copyWith({List<Guess>? guesses, GameStatus? status}) {
    return GameSession._(
      secretWord: secretWord,
      guesses: guesses ?? _guesses,
      status: status ?? this.status,
      maxAttempts: maxAttempts,
    );
  }
}
