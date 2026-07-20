import 'share_card_text.dart';

/// Immutable, privacy-safe display data for the official Daily Challenge
/// win's share card.
///
/// Always built from the *official* (first-of-the-day) result — never a live,
/// possibly-replayed session — so a replay after an official win still shares
/// the exact same card. Carries no secret word, no guessed word, and no
/// wallet balance.
///
/// [currentStreak] is the player's *current persisted* daily-play streak at
/// share time, not a historical snapshot of the streak as it stood the
/// moment the official result completed — this app does not persist
/// per-day streak history, so reconstructing that historical value is not
/// reliably possible. In the overwhelming common case (sharing right after
/// completing today's official challenge) the two are identical anyway,
/// since completing the Daily Challenge is itself what extended the streak
/// to its current value.
class DailyChallengeShareData {
  /// Throws [ArgumentError] if [attemptsUsed] exceeds [maxAttempts], or if
  /// any count is otherwise out of range.
  DailyChallengeShareData({
    required this.dateLabel,
    required this.attemptsUsed,
    required this.maxAttempts,
    required this.hintsUsed,
    required this.coinsEarned,
    required this.currentStreak,
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
    if (currentStreak < 0) {
      throw ArgumentError.value(
        currentStreak,
        'currentStreak',
        'must not be negative',
      );
    }
  }

  /// A short, locale-safe date label, e.g. "20 JULY 2026".
  final String dateLabel;

  /// The number of valid guesses used in the official attempt.
  final int attemptsUsed;

  /// The maximum number of valid guesses that were allowed.
  final int maxAttempts;

  /// The number of hints used in the official attempt. `0` shows "No hints
  /// used".
  final int hintsUsed;

  /// The coins earned for the official Daily Challenge win.
  final int coinsEarned;

  /// The player's current persisted daily-play streak. See the class-level
  /// doc for why this is the current value rather than a historical one.
  final int currentStreak;

  /// "Solved in 4/10 attempts".
  String get attemptsLabel => shareCardAttemptsLabel(attemptsUsed, maxAttempts);

  /// "No hints used", "1 hint used", or "N hints used".
  String get hintsLabel => shareCardHintsLabel(hintsUsed);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyChallengeShareData &&
          other.dateLabel == dateLabel &&
          other.attemptsUsed == attemptsUsed &&
          other.maxAttempts == maxAttempts &&
          other.hintsUsed == hintsUsed &&
          other.coinsEarned == coinsEarned &&
          other.currentStreak == currentStreak);

  @override
  int get hashCode => Object.hash(
    dateLabel,
    attemptsUsed,
    maxAttempts,
    hintsUsed,
    coinsEarned,
    currentStreak,
  );
}
