import '../../../core/time/local_date.dart';
import '../models/daily_challenge_result.dart';

/// Formats an official [DailyChallengeResult] into privacy-safe, shareable
/// text.
///
/// Deliberately never reads a secret word or a guessed word — [result]
/// itself carries neither, only each guess's aggregate bulls/cows (see
/// `DailyChallengeGuessRecord`) — mirroring `GameResultShareFormatter`'s
/// privacy stance for normal games. Pure and deterministic: the same
/// [result] and [currentStreak] always format to the same text.
///
/// Always formats [result] — the official, first-completion record — never
/// a live, possibly-replayed session; the app-level composition root is
/// responsible for always passing the official result here, even when the
/// player is sharing from a practice replay (see CLAUDE.md-adjacent
/// milestone rule: "a replay must not overwrite the official result" —
/// sharing follows the same rule for consistency).
class DailyChallengeResultShareFormatter {
  const DailyChallengeResultShareFormatter();

  static const String _appName = 'Cow Bull Quest';

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Builds the shareable text for [result]. [currentStreak] is the
  /// player's current streak length at share time, included as a final line
  /// only when it is meaningful (greater than zero) — a zero streak is
  /// simply omitted rather than shown.
  String format({required DailyChallengeResult result, int? currentStreak}) {
    final buffer = StringBuffer()
      ..writeln('$_appName — Daily Challenge')
      ..writeln(_formatDate(result.date))
      ..writeln();

    for (final guess in result.guesses) {
      buffer.writeln(
        'Guess ${guess.turnNumber}: '
        '🟩 ${_countWithNoun(guess.bulls, 'Bull', 'Bulls')} · '
        '🟨 ${_countWithNoun(guess.cows, 'Cow', 'Cows')}',
      );
    }
    if (result.guesses.isNotEmpty) buffer.writeln();

    buffer.writeln(
      result.won
          ? 'Solved in ${result.attemptsUsed}/${result.maxAttempts} attempts'
          : 'Not solved in ${result.maxAttempts} attempts',
    );
    if (result.hintsUsed > 0) {
      buffer.writeln(
        _countWithNoun(result.hintsUsed, 'hint used', 'hints used'),
      );
    }
    if (currentStreak != null && currentStreak > 0) {
      buffer.write('🔥 $currentStreak-day streak');
    }

    return buffer.toString().trimRight();
  }

  String _formatDate(LocalDate date) =>
      '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

  String _countWithNoun(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';
}
