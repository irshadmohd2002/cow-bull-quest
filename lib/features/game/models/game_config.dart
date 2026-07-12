/// Immutable configuration for one game: the secret word's length and the
/// maximum number of valid guesses allowed before the game is lost.
///
/// [maxAttempts] is always derived internally from [wordLength] — there is
/// no constructor path that accepts them independently — so an inconsistent
/// combination (e.g. `wordLength: 4` paired with 20 attempts) cannot be
/// constructed.
class GameConfig {
  GameConfig._({required this.wordLength, required this.maxAttempts});

  /// Builds the configuration for [wordLength].
  ///
  /// Throws [ArgumentError] if [wordLength] is not one of the supported
  /// lengths (4, 5, or 6). This is checked at runtime rather than left to an
  /// `assert`, since an unsupported length would otherwise surface much
  /// later as a confusing failure when starting or scoring a game — in a
  /// release build an `assert` would not fire at all.
  factory GameConfig.forWordLength(int wordLength) {
    final maxAttempts = _maxAttemptsByWordLength[wordLength];
    if (maxAttempts == null) {
      throw ArgumentError.value(
        wordLength,
        'wordLength',
        'unsupported word length; must be one of '
            '${_maxAttemptsByWordLength.keys.toList()}',
      );
    }
    return GameConfig._(wordLength: wordLength, maxAttempts: maxAttempts);
  }

  static const Map<int, int> _maxAttemptsByWordLength = {4: 10, 5: 15, 6: 20};

  /// The secret word's length for this configuration.
  final int wordLength;

  /// The maximum number of valid guesses allowed before the game is lost.
  final int maxAttempts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameConfig &&
          other.wordLength == wordLength &&
          other.maxAttempts == maxAttempts);

  @override
  int get hashCode => Object.hash(wordLength, maxAttempts);

  @override
  String toString() =>
      'GameConfig(wordLength: $wordLength, maxAttempts: $maxAttempts)';
}
