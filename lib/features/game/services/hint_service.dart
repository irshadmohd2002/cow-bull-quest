import '../models/guess.dart';
import '../models/revealed_hint.dart';

/// The outcome of [HintService.computeHint]: either [HintComputed], with
/// the next hint to reveal, or [NoHintAvailable] when every letter position
/// is already known and there is nothing left a hint could usefully add.
sealed class HintComputation {
  const HintComputation();
}

/// A useful hint is available: [hint] is the next position/letter to reveal.
final class HintComputed extends HintComputation {
  const HintComputed(this.hint);

  final RevealedHint hint;
}

/// No useful hint remains — every position is already known from a Bull in
/// an accepted guess or from an earlier hint.
final class NoHintAvailable extends HintComputation {
  const NoHintAvailable();
}

/// Computes which position and letter the next hint should reveal.
///
/// Stateless and deterministic: given the same secret word, guess history,
/// and previously revealed hints, [computeHint] always returns the same
/// result — the lowest-index letter position that is neither an
/// already-known Bull (a position where some accepted guess's letter
/// matched the secret word in that exact spot) nor already revealed by an
/// earlier hint this game. Determinism — rather than randomness — is what
/// this milestone's "tests must be stable" requirement calls for while
/// still satisfying "never reveal a known Bull position" and "never repeat
/// a previously hinted position".
///
/// A guess's per-position Bull status is derived here by comparing each
/// guess's word against [secretWord] letter-by-letter, rather than reading
/// [Guess.result] — [GuessResult] only carries aggregate bulls/cows counts,
/// not which positions were bulls, so this is the only way to recover that
/// detail without changing the core scoring model.
class HintService {
  const HintService();

  /// Returns the next hint to reveal for [secretWord], given [guesses]
  /// accepted so far this game and [previousHints] already revealed this
  /// game.
  HintComputation computeHint({
    required String secretWord,
    required List<Guess> guesses,
    required List<RevealedHint> previousHints,
  }) {
    final knownPositions = <int>{
      for (final hint in previousHints) hint.position,
    };
    for (final guess in guesses) {
      for (var i = 0; i < secretWord.length; i++) {
        if (guess.word[i] == secretWord[i]) {
          knownPositions.add(i);
        }
      }
    }
    for (var position = 0; position < secretWord.length; position++) {
      if (!knownPositions.contains(position)) {
        return HintComputed(
          RevealedHint(position: position, letter: secretWord[position]),
        );
      }
    }
    return const NoHintAvailable();
  }
}
