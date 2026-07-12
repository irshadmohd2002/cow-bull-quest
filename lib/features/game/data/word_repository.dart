/// Provides the game-ready word lists generated under `assets/generated/`
/// (see `docs/word_lists.md`): the broad allowed-guess vocabulary and the
/// smaller common-word set used to pick secret words.
///
/// Implementations must return immutable collections — callers must never
/// be able to mutate cached word lists.
abstract class WordRepository {
  /// Word lengths this milestone generates lists for.
  static const List<int> supportedLengths = [4, 5, 6];

  /// The full allowed-guess list for [wordLength], sorted and deduplicated.
  Future<List<String>> loadAllowedWords(int wordLength);

  /// The secret-word candidate list for [wordLength], sorted and
  /// deduplicated. Every entry is guaranteed to also appear in
  /// [loadAllowedWords] for the same length.
  Future<List<String>> loadSecretWords(int wordLength);

  /// Whether [word] — normalized before comparison — appears in the
  /// allowed-guess list for [wordLength].
  Future<bool> isAllowed(String word, int wordLength);

  /// Picks one word from the secret-word list for [wordLength].
  Future<String> selectSecretWord(int wordLength);
}
