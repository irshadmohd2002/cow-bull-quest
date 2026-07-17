import '../../../core/time/local_date.dart';

/// One guess's aggregate score within a completed Daily Challenge, kept only
/// so the official result can later be re-rendered as shareable text (see
/// `DailyChallengeResultShareFormatter`) without needing the live game
/// session anymore.
///
/// Deliberately carries no guessed word — only [turnNumber] and the scored
/// [bulls]/[cows] — mirroring `GameResultShareFormatter`'s existing privacy
/// stance of never persisting or sharing guessed words.
class DailyChallengeGuessRecord {
  const DailyChallengeGuessRecord({
    required this.turnNumber,
    required this.bulls,
    required this.cows,
  });

  final int turnNumber;
  final int bulls;
  final int cows;

  Map<String, Object?> toJson() => {
    'turnNumber': turnNumber,
    'bulls': bulls,
    'cows': cows,
  };

  factory DailyChallengeGuessRecord.fromJson(Map<String, Object?> json) {
    final turnNumber = json['turnNumber'];
    final bulls = json['bulls'];
    final cows = json['cows'];
    if (turnNumber is! int) {
      throw const FormatException('guess record "turnNumber" must be an int');
    }
    if (bulls is! int) {
      throw const FormatException('guess record "bulls" must be an int');
    }
    if (cows is! int) {
      throw const FormatException('guess record "cows" must be an int');
    }
    return DailyChallengeGuessRecord(
      turnNumber: turnNumber,
      bulls: bulls,
      cows: cows,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyChallengeGuessRecord &&
          other.turnNumber == turnNumber &&
          other.bulls == bulls &&
          other.cows == cows);

  @override
  int get hashCode => Object.hash(turnNumber, bulls, cows);
}

/// The official, immutable record of one local calendar date's completed
/// Daily Challenge.
///
/// "Official" means the *first* completed attempt for [date] — see
/// `DailyChallengeRepository.recordIfFirst` — a later practice replay on the
/// same date never produces a second [DailyChallengeResult] or changes this
/// one. Deliberately carries no secret word and no guessed words, only
/// [guesses]' aggregate bulls/cows per turn — enough to reconstruct
/// privacy-safe shareable text (matching `GameResultShareFormatter`'s own
/// scope) at any later time, even after a replay.
class DailyChallengeResult {
  /// Throws [ArgumentError] if [attemptsUsed] exceeds [maxAttempts], or
  /// either is not positive.
  DailyChallengeResult({
    required this.date,
    required this.won,
    required this.attemptsUsed,
    required this.maxAttempts,
    required this.hintsUsed,
    required this.completedAt,
    required this.wordListVersion,
    required List<DailyChallengeGuessRecord> guesses,
  }) : guesses = List.unmodifiable(guesses) {
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
  }

  /// The local calendar date this challenge was for.
  final LocalDate date;

  /// Whether the official attempt was won.
  final bool won;

  /// The number of valid guesses used in the official attempt.
  final int attemptsUsed;

  /// The maximum number of valid guesses that were allowed.
  final int maxAttempts;

  /// The number of hints used in the official attempt.
  final int hintsUsed;

  /// When the official attempt completed.
  final DateTime completedAt;

  /// The `DailyChallengeService.wordListVersion` in effect when this
  /// challenge's secret word was selected — retained so a past record stays
  /// interpretable even if a future app version changes the eligible word
  /// pool or bumps that version; this result's own displayed data (date,
  /// outcome, attempts, hints) never depends on it.
  final int wordListVersion;

  /// The aggregate bulls/cows for every guess made in the official attempt,
  /// oldest first.
  final List<DailyChallengeGuessRecord> guesses;

  static const int _documentVersion = 1;

  Map<String, Object?> toJson() => {
    'version': _documentVersion,
    'date': date.toIso8601String(),
    'won': won,
    'attemptsUsed': attemptsUsed,
    'maxAttempts': maxAttempts,
    'hintsUsed': hintsUsed,
    'completedAt': completedAt.toIso8601String(),
    'wordListVersion': wordListVersion,
    'guesses': [for (final guess in guesses) guess.toJson()],
  };

  /// Rebuilds a [DailyChallengeResult] from a JSON-compatible [json] map, as
  /// produced by [toJson].
  ///
  /// Throws [FormatException] if a required field is missing, has the wrong
  /// type, carries an unrecognized document version, or (for [date]/
  /// [completedAt]) is not a valid date/timestamp string. Throws
  /// [ArgumentError] if the reconstructed values fail the same validation
  /// the default constructor enforces.
  factory DailyChallengeResult.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != _documentVersion) {
      throw FormatException(
        'unsupported Daily Challenge result document version: $version',
      );
    }
    final rawDate = json['date'];
    if (rawDate is! String) {
      throw const FormatException(
        'Daily Challenge result "date" must be a string',
      );
    }
    final date = LocalDate.tryParse(rawDate);
    if (date == null) {
      throw FormatException(
        'Daily Challenge result "date" is not a valid date: $rawDate',
      );
    }
    final won = json['won'];
    if (won is! bool) {
      throw const FormatException(
        'Daily Challenge result "won" must be a bool',
      );
    }
    final attemptsUsed = json['attemptsUsed'];
    if (attemptsUsed is! int) {
      throw const FormatException(
        'Daily Challenge result "attemptsUsed" must be an int',
      );
    }
    final maxAttempts = json['maxAttempts'];
    if (maxAttempts is! int) {
      throw const FormatException(
        'Daily Challenge result "maxAttempts" must be an int',
      );
    }
    final hintsUsed = json['hintsUsed'];
    if (hintsUsed is! int) {
      throw const FormatException(
        'Daily Challenge result "hintsUsed" must be an int',
      );
    }
    final rawCompletedAt = json['completedAt'];
    if (rawCompletedAt is! String) {
      throw const FormatException(
        'Daily Challenge result "completedAt" must be a string',
      );
    }
    final completedAt = DateTime.tryParse(rawCompletedAt);
    if (completedAt == null) {
      throw FormatException(
        'Daily Challenge result "completedAt" is not a valid ISO-8601 '
        'timestamp: $rawCompletedAt',
      );
    }
    final wordListVersion = json['wordListVersion'];
    if (wordListVersion is! int) {
      throw const FormatException(
        'Daily Challenge result "wordListVersion" must be an int',
      );
    }
    final rawGuesses = json['guesses'];
    if (rawGuesses is! List) {
      throw const FormatException(
        'Daily Challenge result "guesses" must be an array',
      );
    }
    final guesses = [
      for (final entry in rawGuesses)
        DailyChallengeGuessRecord.fromJson(
          (entry as Map).cast<String, Object?>(),
        ),
    ];

    return DailyChallengeResult(
      date: date,
      won: won,
      attemptsUsed: attemptsUsed,
      maxAttempts: maxAttempts,
      hintsUsed: hintsUsed,
      completedAt: completedAt,
      wordListVersion: wordListVersion,
      guesses: guesses,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyChallengeResult &&
          other.date == date &&
          other.won == won &&
          other.attemptsUsed == attemptsUsed &&
          other.maxAttempts == maxAttempts &&
          other.hintsUsed == hintsUsed &&
          other.completedAt == completedAt &&
          other.wordListVersion == wordListVersion &&
          _guessesEqual(other.guesses, guesses));

  static bool _guessesEqual(
    List<DailyChallengeGuessRecord> a,
    List<DailyChallengeGuessRecord> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    date,
    won,
    attemptsUsed,
    maxAttempts,
    hintsUsed,
    completedAt,
    wordListVersion,
    Object.hashAll(guesses),
  );
}
