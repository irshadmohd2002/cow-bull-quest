/// The secret-word difficulty pool a game is started with.
///
/// Affects only which secret-word pool [WordRepository] draws from when a
/// game starts — see `docs/word_lists.md` for how each pool is built. It
/// never changes scoring, allowed-guess validation, duplicate-letter
/// behavior, or attempt limits. Carries no human-facing text; presentation
/// code owns how each value is labeled and described.
enum GameDifficulty {
  /// Drawn from the most frequent quarter of ranked secret-word
  /// candidates: familiar, high-frequency words.
  easy,

  /// Drawn from the middle half of ranked secret-word candidates: broader
  /// everyday vocabulary.
  common,

  /// Drawn from the least frequent quarter of ranked secret-word
  /// candidates: less frequent words.
  hard,
}
