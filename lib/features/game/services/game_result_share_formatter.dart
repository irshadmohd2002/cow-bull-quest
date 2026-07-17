import '../models/game_difficulty.dart';
import '../models/game_session.dart';
import '../models/game_status.dart';
import '../models/guess.dart';
import '../models/guess_result.dart';

/// Formats a completed [GameSession] into privacy-safe, shareable text.
///
/// Deliberately never reads [GameSession.secretWord] or any [Guess.word]:
/// only each guess's [Guess.turnNumber] and its scored
/// [GuessResult.bulls]/[GuessResult.cows] are rendered. [GuessResult] stores
/// aggregate bulls/cows only — it has no per-letter/per-position outcome —
/// so this formatter renders one honest aggregate-score line per guess
/// rather than fabricating Wordle-style per-position tiles it has no data
/// for.
///
/// Pure and deterministic: no platform calls, no randomness, and no
/// dependency on the current time, so the same [GameSession] always formats
/// to the exact same text.
class GameResultShareFormatter {
  const GameResultShareFormatter();

  static const String _appName = 'Cow Bull Quest';

  /// Builds the shareable text for [session], which must be completed
  /// (`session.status` of [GameStatus.won] or [GameStatus.lost]).
  /// [difficulty] is the pool the game's secret word was drawn from, and
  /// [hintsUsed] is the number of hints used this game; the hints line is
  /// omitted entirely when it is zero.
  String format({
    required GameSession session,
    required GameDifficulty difficulty,
    required int hintsUsed,
  }) {
    final won = session.status == GameStatus.won;
    final buffer = StringBuffer()
      ..writeln('$_appName — ${_difficultyLabel(difficulty)}')
      ..writeln();

    for (final guess in session.guesses) {
      buffer.writeln(
        'Guess ${guess.turnNumber}: '
        '🟩 ${_countWithNoun(guess.result.bulls, 'Bull', 'Bulls')} · '
        '🟨 ${_countWithNoun(guess.result.cows, 'Cow', 'Cows')}',
      );
    }
    if (session.guesses.isNotEmpty) buffer.writeln();

    buffer.writeln(
      won
          ? 'Solved in ${session.attemptsUsed}/${session.maxAttempts} attempts'
          : 'Not solved in ${session.maxAttempts} attempts',
    );
    if (hintsUsed > 0) {
      buffer.writeln(_countWithNoun(hintsUsed, 'hint used', 'hints used'));
    }

    if (won) {
      buffer
        ..writeln()
        ..write('Can you solve it?');
    }

    return buffer.toString().trimRight();
  }

  String _countWithNoun(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';

  String _difficultyLabel(GameDifficulty difficulty) => switch (difficulty) {
    GameDifficulty.easy => 'Easy',
    GameDifficulty.common => 'Medium',
    GameDifficulty.hard => 'Hard',
  };
}
