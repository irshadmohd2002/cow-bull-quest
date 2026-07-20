import 'share_card_text.dart';

/// Immutable, privacy-safe display data for a normal (non-Daily-Challenge)
/// game win's share card.
///
/// Deliberately carries no secret word, no guessed word, and no wallet
/// balance — only what the card is allowed to show (see CLAUDE.md-adjacent
/// milestone privacy rules). [difficultyLabel] is already-resolved,
/// human-facing text ("Easy"/"Medium"/"Hard") supplied by the caller, rather
/// than the `game` feature's own `GameDifficulty` — this model lives in the
/// shared `models/` layer and must stay feature-agnostic.
class NormalWinShareData {
  /// Throws [ArgumentError] if [attemptsUsed] exceeds [maxAttempts], or if
  /// [attemptsUsed], [maxAttempts], [hintsUsed], or [coinsEarned] is
  /// otherwise out of range.
  NormalWinShareData({
    required this.difficultyLabel,
    required this.attemptsUsed,
    required this.maxAttempts,
    required this.hintsUsed,
    required this.coinsEarned,
  }) {
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be >= 1');
    }
    if (attemptsUsed < 1) {
      throw ArgumentError.value(attemptsUsed, 'attemptsUsed', 'must be >= 1');
    }
    if (attemptsUsed > maxAttempts) {
      throw ArgumentError.value(
        attemptsUsed,
        'attemptsUsed',
        'must not exceed maxAttempts ($maxAttempts)',
      );
    }
    if (hintsUsed < 0) {
      throw ArgumentError.value(hintsUsed, 'hintsUsed', 'must not be negative');
    }
    if (coinsEarned < 0) {
      throw ArgumentError.value(
        coinsEarned,
        'coinsEarned',
        'must not be negative',
      );
    }
  }

  /// Already-resolved difficulty label ("Easy", "Medium", or "Hard").
  final String difficultyLabel;

  /// The number of valid guesses used to win.
  final int attemptsUsed;

  /// The maximum number of valid guesses that were allowed.
  final int maxAttempts;

  /// The number of hints used this game. `0` shows "No hints used".
  final int hintsUsed;

  /// Coins earned by this win. The card omits the coins row entirely when
  /// this is `0`.
  final int coinsEarned;

  /// "Solved in 4/10 attempts".
  String get attemptsLabel => shareCardAttemptsLabel(attemptsUsed, maxAttempts);

  /// "No hints used", "1 hint used", or "N hints used".
  String get hintsLabel => shareCardHintsLabel(hintsUsed);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NormalWinShareData &&
          other.difficultyLabel == difficultyLabel &&
          other.attemptsUsed == attemptsUsed &&
          other.maxAttempts == maxAttempts &&
          other.hintsUsed == hintsUsed &&
          other.coinsEarned == coinsEarned);

  @override
  int get hashCode => Object.hash(
    difficultyLabel,
    attemptsUsed,
    maxAttempts,
    hintsUsed,
    coinsEarned,
  );
}
