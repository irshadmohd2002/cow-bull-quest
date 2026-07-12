import '../models/guess_result.dart';

/// Pure scoring logic for a single guess against a secret word.
///
/// Contract: [score] expects `secretWord` and `guess` of equal length and
/// throws [ArgumentError] if they differ, since the duplicate-letter
/// counting algorithm below is only well-defined when every guess letter
/// has a corresponding secret position. Callers (typically the game
/// engine, via the guess validator) are expected to have already checked
/// length and character-set validity; this method lowercases its inputs
/// defensively so it also behaves correctly when exercised directly, e.g.
/// in unit tests, without relying on an external normalization step.
class GuessScorer {
  const GuessScorer();

  /// Scores [guess] against [secretWord].
  ///
  /// Bulls (correct letter, correct position) are counted first and
  /// removed from consideration; cows (correct letter, wrong position) are
  /// then counted from what remains, capped so a letter is never counted
  /// more times than it appears unmatched in the secret word.
  GuessResult score({required String secretWord, required String guess}) {
    final secret = secretWord.toLowerCase();
    final attempt = guess.toLowerCase();
    if (secret.length != attempt.length) {
      throw ArgumentError(
        'secretWord (${secret.length}) and guess (${attempt.length}) '
        'must have the same length',
      );
    }

    var bulls = 0;
    final unmatchedSecretCounts = <String, int>{};
    final unmatchedGuessLetters = <String>[];

    for (var i = 0; i < secret.length; i++) {
      final secretLetter = secret[i];
      final guessLetter = attempt[i];
      if (secretLetter == guessLetter) {
        bulls++;
      } else {
        unmatchedSecretCounts[secretLetter] =
            (unmatchedSecretCounts[secretLetter] ?? 0) + 1;
        unmatchedGuessLetters.add(guessLetter);
      }
    }

    var cows = 0;
    for (final letter in unmatchedGuessLetters) {
      final remaining = unmatchedSecretCounts[letter] ?? 0;
      if (remaining > 0) {
        cows++;
        unmatchedSecretCounts[letter] = remaining - 1;
      }
    }

    return GuessResult(bulls: bulls, cows: cows);
  }
}
