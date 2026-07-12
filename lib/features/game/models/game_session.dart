import 'dart:collection';

import 'game_status.dart';
import 'guess.dart';

final RegExp _alphabeticOnly = RegExp(r'^[a-zA-Z]+$');

/// The immutable state of one game: the secret word, the guesses made so
/// far, and the current [GameStatus].
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
  }) : _guesses = List.unmodifiable(guesses);

  /// Starts a new, in-progress session for [secretWord].
  ///
  /// [secretWord] is normalized to lowercase. Throws [ArgumentError] if it
  /// is empty or contains characters outside `a-z`/`A-Z`: an invalid secret
  /// would make the session permanently unwinnable, so this is rejected at
  /// creation rather than left to surface confusingly later.
  factory GameSession.start(String secretWord) {
    if (!_alphabeticOnly.hasMatch(secretWord)) {
      throw ArgumentError.value(
        secretWord,
        'secretWord',
        'must be non-empty and contain only letters a-z',
      );
    }
    return GameSession._(
      secretWord: secretWord.toLowerCase(),
      guesses: const [],
      status: GameStatus.inProgress,
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

  /// Returns a new session with the given fields replaced; leaves this
  /// instance untouched.
  GameSession copyWith({List<Guess>? guesses, GameStatus? status}) {
    return GameSession._(
      secretWord: secretWord,
      guesses: guesses ?? _guesses,
      status: status ?? this.status,
    );
  }
}
