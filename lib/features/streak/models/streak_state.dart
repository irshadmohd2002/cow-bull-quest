import '../../../core/time/local_date.dart';

/// The immutable, persisted state of the player's daily-play streak.
///
/// A "streak day" is earned by completing at least one game — normal or
/// Daily Challenge, won or lost — on a given local calendar date;
/// abandoning or restarting an unfinished game never earns one. See
/// `StreakService` for the transition rules that produce a new
/// [StreakState] from the previous one.
class StreakState {
  /// Throws [ArgumentError] if either streak is negative, or if
  /// [currentStreak] exceeds [longestStreak] — the longest streak can never
  /// be less than the streak currently in progress.
  StreakState({
    required this.currentStreak,
    required this.longestStreak,
    this.lastQualifyingDate,
  }) {
    if (currentStreak < 0) {
      throw ArgumentError.value(
        currentStreak,
        'currentStreak',
        'must not be negative',
      );
    }
    if (longestStreak < 0) {
      throw ArgumentError.value(
        longestStreak,
        'longestStreak',
        'must not be negative',
      );
    }
    if (currentStreak > longestStreak) {
      throw ArgumentError.value(
        currentStreak,
        'currentStreak',
        'must not exceed longestStreak ($longestStreak)',
      );
    }
  }

  /// A new installation's starting streak state: no streak yet, on either
  /// counter.
  factory StreakState.empty() =>
      StreakState(currentStreak: 0, longestStreak: 0);

  /// The number of consecutive qualifying calendar days ending with
  /// [lastQualifyingDate]. `0` if no qualifying day has ever been recorded.
  final int currentStreak;

  /// The longest [currentStreak] ever reached. Never decreases.
  final int longestStreak;

  /// The most recent local calendar date a qualifying game was completed on,
  /// or `null` if none ever has been.
  final LocalDate? lastQualifyingDate;

  /// The document version this is serialized as. Bumped only if a future
  /// change to this shape requires migrating older stored documents.
  static const int _documentVersion = 1;

  /// Serializes this state to a JSON-compatible map.
  Map<String, Object?> toJson() => {
    'version': _documentVersion,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastQualifyingDate': lastQualifyingDate?.toIso8601String(),
  };

  /// Rebuilds a [StreakState] from a JSON-compatible [json] map, as produced
  /// by [toJson].
  ///
  /// Throws [FormatException] if a required field is missing, has the wrong
  /// type, carries an unrecognized document version, or (for
  /// [lastQualifyingDate]) is not a valid ISO-8601 date string. Throws
  /// [ArgumentError] if the reconstructed values fail the same validation
  /// the default constructor enforces (e.g. a negative streak). Callers —
  /// see `LocalStreakRepository` — treat both as "malformed data" and
  /// recover to [StreakState.empty] rather than letting either propagate
  /// into gameplay.
  factory StreakState.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != _documentVersion) {
      throw FormatException('unsupported streak document version: $version');
    }
    final currentStreak = json['currentStreak'];
    final longestStreak = json['longestStreak'];
    if (currentStreak is! int) {
      throw const FormatException('streak "currentStreak" must be an int');
    }
    if (longestStreak is! int) {
      throw const FormatException('streak "longestStreak" must be an int');
    }
    final rawLastQualifyingDate = json['lastQualifyingDate'];
    LocalDate? lastQualifyingDate;
    if (rawLastQualifyingDate != null) {
      if (rawLastQualifyingDate is! String) {
        throw const FormatException(
          'streak "lastQualifyingDate" must be a string or null',
        );
      }
      lastQualifyingDate = LocalDate.tryParse(rawLastQualifyingDate);
      if (lastQualifyingDate == null) {
        throw FormatException(
          'streak "lastQualifyingDate" is not a valid date: '
          '$rawLastQualifyingDate',
        );
      }
    }
    return StreakState(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastQualifyingDate: lastQualifyingDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreakState &&
          other.currentStreak == currentStreak &&
          other.longestStreak == longestStreak &&
          other.lastQualifyingDate == lastQualifyingDate);

  @override
  int get hashCode =>
      Object.hash(currentStreak, longestStreak, lastQualifyingDate);

  @override
  String toString() =>
      'StreakState(currentStreak: $currentStreak, '
      'longestStreak: $longestStreak, '
      'lastQualifyingDate: $lastQualifyingDate)';
}
