import '../../../models/difficulty_selection.dart';

/// Stable string values for [DifficultyOption], used wherever the
/// `statistics` feature persists a difficulty — never the enum index, which
/// is not stable across releases if values are reordered.
extension DifficultyOptionStorage on DifficultyOption {
  String get storageValue => switch (this) {
    DifficultyOption.easy => 'easy',
    DifficultyOption.common => 'common',
    DifficultyOption.hard => 'hard',
  };
}

/// Parses a [DifficultyOption] from its
/// [DifficultyOptionStorage.storageValue].
///
/// Throws [FormatException] if [value] is not a recognized difficulty
/// string.
DifficultyOption difficultyOptionFromStorage(String value) => switch (value) {
  'easy' => DifficultyOption.easy,
  'common' => DifficultyOption.common,
  'hard' => DifficultyOption.hard,
  _ => throw FormatException('unknown difficulty value: $value'),
};
