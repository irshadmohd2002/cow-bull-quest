/// The outcome of scoring a single guess against a secret word: how many
/// letters are correct and in position (bulls) versus correct but
/// misplaced (cows).
class GuessResult {
  GuessResult({required this.bulls, required this.cows}) {
    if (bulls < 0) {
      throw ArgumentError.value(bulls, 'bulls', 'must not be negative');
    }
    if (cows < 0) {
      throw ArgumentError.value(cows, 'cows', 'must not be negative');
    }
  }

  /// Number of letters that are correct and in the correct position.
  final int bulls;

  /// Number of letters that are correct but in the wrong position.
  final int cows;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuessResult && other.bulls == bulls && other.cows == cows);

  @override
  int get hashCode => Object.hash(bulls, cows);

  @override
  String toString() => 'GuessResult(bulls: $bulls, cows: $cows)';
}
