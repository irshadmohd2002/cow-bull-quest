import 'guess_result.dart';

/// A single submitted guess: the normalized word the player entered, its
/// scored [result], and the 1-based [turnNumber] it was made on.
///
/// [turnNumber] is included because it is cheap to keep consistent (the
/// engine assigns it as `history.length + 1` when appending) and it lets a
/// future UI label guesses ("Guess #3") without recomputing the index from
/// list position every time it renders history.
class Guess {
  Guess({required this.word, required this.result, required this.turnNumber}) {
    if (turnNumber < 1) {
      throw ArgumentError.value(turnNumber, 'turnNumber', 'must be >= 1');
    }
  }

  /// The normalized (lowercase) guess word.
  final String word;

  /// The scored bulls/cows for this guess.
  final GuessResult result;

  /// The 1-based position of this guess within the game's history.
  final int turnNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Guess &&
          other.word == word &&
          other.result == result &&
          other.turnNumber == turnNumber);

  @override
  int get hashCode => Object.hash(word, result, turnNumber);

  @override
  String toString() =>
      'Guess(word: $word, result: $result, turnNumber: $turnNumber)';
}
