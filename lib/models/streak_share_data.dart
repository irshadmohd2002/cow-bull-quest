/// Immutable display data for a current-streak share card.
///
/// Only ever constructed for a positive [currentStreak] — sharing a `0`
/// streak is never offered (see the milestone's "do not share when current
/// streak is 0" rule) — so the constructor rejects `0` and negative values
/// rather than silently allowing a card that should never exist.
class StreakShareData {
  /// Throws [ArgumentError] if [currentStreak] is less than 1.
  StreakShareData({required this.currentStreak}) {
    if (currentStreak < 1) {
      throw ArgumentError.value(
        currentStreak,
        'currentStreak',
        'must be >= 1; a 0 streak is never shareable',
      );
    }
  }

  /// The player's current daily-play streak, in days. Always >= 1.
  final int currentStreak;

  /// Exact milestone conversions the card shows as a subtitle, e.g. "1
  /// WEEK" for a 7-day streak. Only these specific values ever get a
  /// subtitle — no arbitrary value is ever approximated, so a non-milestone
  /// streak (e.g. 10 days) simply has no subtitle at all.
  static const Map<int, String> _milestoneLabels = {
    7: '1 WEEK',
    14: '2 WEEKS',
    21: '3 WEEKS',
    30: '1 MONTH',
    60: '2 MONTHS',
    90: '3 MONTHS',
    180: '6 MONTHS',
    365: '1 YEAR',
    730: '2 YEARS',
  };

  /// The exact milestone label for [currentStreak], or `null` if
  /// [currentStreak] is not one of the exact milestone day counts.
  String? get milestoneLabel => _milestoneLabels[currentStreak];

  /// The card's primary "N DAY STREAK" text, correctly singular at exactly
  /// one day.
  String get primaryLabel =>
      '$currentStreak ${currentStreak == 1 ? 'DAY' : 'DAYS'} STREAK';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreakShareData && other.currentStreak == currentStreak);

  @override
  int get hashCode => currentStreak.hashCode;
}
