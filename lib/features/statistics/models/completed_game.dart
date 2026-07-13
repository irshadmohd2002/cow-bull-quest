import '../../../models/difficulty_selection.dart';
import 'difficulty_storage.dart';
import 'game_outcome.dart';

/// The secret-word lengths a completed game may have been played at.
///
/// Kept as its own constant here — rather than imported from the `game`
/// feature's `GameConfig` — because the `statistics` feature must never
/// import a `game`-feature file; the app-level composition root is
/// responsible for only ever constructing a [CompletedGame] with a length
/// that is actually supported by the game feature.
const List<int> supportedCompletedGameWordLengths = [4, 5, 6];

/// One immutable, neutral record of a finished game, kept only for local
/// statistics.
///
/// Deliberately carries no secret word, guess words, or score detail — only
/// what aggregate statistics need: [wordLength], [difficulty], [outcome],
/// and the attempt counts. [difficulty] uses the shared, feature-neutral
/// [DifficultyOption] — already used by `home` to offer a difficulty choice
/// — rather than the `game` feature's own `GameDifficulty`, so this feature
/// never has to import `game` just to describe a finished game's difficulty;
/// the app-level composition root already has the [DifficultyOption] on hand
/// when it starts a game, and passes it straight through here when that game
/// completes.
class CompletedGame {
  /// Builds a validated completed-game record.
  ///
  /// Throws [ArgumentError] if [id] is empty, [wordLength] is not one of
  /// [supportedCompletedGameWordLengths], [maxAttempts] or [attemptsUsed] is
  /// not positive, or [attemptsUsed] exceeds [maxAttempts].
  CompletedGame({
    required this.id,
    required this.completedAt,
    required this.wordLength,
    required this.difficulty,
    required this.outcome,
    required this.attemptsUsed,
    required this.maxAttempts,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (!supportedCompletedGameWordLengths.contains(wordLength)) {
      throw ArgumentError.value(
        wordLength,
        'wordLength',
        'unsupported word length; must be one of '
            '$supportedCompletedGameWordLengths',
      );
    }
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
  }

  /// Rebuilds a [CompletedGame] from a JSON-compatible [json] map, as
  /// produced by [toJson].
  ///
  /// Throws [FormatException] if a required field is missing, has the wrong
  /// type, or (for [difficulty]/[outcome]) is not a recognized stable
  /// string. Throws [ArgumentError] if the reconstructed values fail the
  /// same validation the default constructor enforces.
  factory CompletedGame.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final completedAt = json['completedAt'];
    final wordLength = json['wordLength'];
    final difficulty = json['difficulty'];
    final outcome = json['outcome'];
    final attemptsUsed = json['attemptsUsed'];
    final maxAttempts = json['maxAttempts'];

    if (id is! String) {
      throw const FormatException('completed game "id" must be a string');
    }
    if (completedAt is! String) {
      throw const FormatException(
        'completed game "completedAt" must be a string',
      );
    }
    if (wordLength is! int) {
      throw const FormatException('completed game "wordLength" must be an int');
    }
    if (difficulty is! String) {
      throw const FormatException(
        'completed game "difficulty" must be a string',
      );
    }
    if (outcome is! String) {
      throw const FormatException('completed game "outcome" must be a string');
    }
    if (attemptsUsed is! int) {
      throw const FormatException(
        'completed game "attemptsUsed" must be an int',
      );
    }
    if (maxAttempts is! int) {
      throw const FormatException(
        'completed game "maxAttempts" must be an int',
      );
    }

    final parsedCompletedAt = DateTime.tryParse(completedAt);
    if (parsedCompletedAt == null) {
      throw FormatException(
        'completed game "completedAt" is not a valid ISO-8601 timestamp: '
        '$completedAt',
      );
    }

    return CompletedGame(
      id: id,
      completedAt: parsedCompletedAt,
      wordLength: wordLength,
      difficulty: difficultyOptionFromStorage(difficulty),
      outcome: gameOutcomeFromStorage(outcome),
      attemptsUsed: attemptsUsed,
      maxAttempts: maxAttempts,
    );
  }

  /// Stable unique identifier for this result, used to guard against
  /// recording the same completed game twice.
  final String id;

  /// When this game finished.
  final DateTime completedAt;

  /// The secret word's length (one of [supportedCompletedGameWordLengths]).
  final int wordLength;

  /// Which difficulty pool the secret word was drawn from.
  final DifficultyOption difficulty;

  /// Whether the game was won or lost.
  final GameOutcome outcome;

  /// The number of valid guesses used.
  final int attemptsUsed;

  /// The maximum number of valid guesses that were allowed.
  final int maxAttempts;

  /// Serializes this record to a JSON-compatible map, using stable string
  /// values for [difficulty] and [outcome] — never enum indexes.
  Map<String, Object?> toJson() => {
    'id': id,
    'completedAt': completedAt.toIso8601String(),
    'wordLength': wordLength,
    'difficulty': difficulty.storageValue,
    'outcome': outcome.storageValue,
    'attemptsUsed': attemptsUsed,
    'maxAttempts': maxAttempts,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletedGame &&
          other.id == id &&
          other.completedAt == completedAt &&
          other.wordLength == wordLength &&
          other.difficulty == difficulty &&
          other.outcome == outcome &&
          other.attemptsUsed == attemptsUsed &&
          other.maxAttempts == maxAttempts);

  @override
  int get hashCode => Object.hash(
    id,
    completedAt,
    wordLength,
    difficulty,
    outcome,
    attemptsUsed,
    maxAttempts,
  );

  @override
  String toString() =>
      'CompletedGame(id: $id, completedAt: $completedAt, '
      'wordLength: $wordLength, difficulty: $difficulty, outcome: $outcome, '
      'attemptsUsed: $attemptsUsed, maxAttempts: $maxAttempts)';
}
