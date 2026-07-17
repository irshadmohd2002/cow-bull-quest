import 'word_repository.dart';
import '../models/game_difficulty.dart';

/// A [WordRepository] decorator that always returns one fixed word from
/// [selectSecretWord], regardless of the requested [GameDifficulty], while
/// delegating every other method (allowed-guess loading/validation,
/// secret-word pool loading) to [delegate] unchanged.
///
/// Exists so a game whose secret word must be chosen by something other
/// than [WordRepository]'s own random selection — currently, the Daily
/// Challenge's deterministic date-based word (see
/// `features/daily_challenge/services/daily_challenge_service.dart`) — can
/// still be played through the ordinary [GameController]/[GameConfig]
/// pipeline unmodified. Kept feature-local to `game` (rather than under
/// `daily_challenge`) since it has no knowledge of Daily Challenge, dates,
/// or determinism at all — it is a small, generic decorator over this
/// feature's own [WordRepository] interface; the app-level composition
/// root is what actually computes [secretWord] and wires this in for a
/// Daily Challenge game, keeping the `daily_challenge` and `game` features
/// mutually unaware of each other.
class FixedSecretWordRepository implements WordRepository {
  const FixedSecretWordRepository({
    required WordRepository delegate,
    required String secretWord,
  }) : _delegate = delegate, // ignore: prefer_initializing_formals
       _secretWord = secretWord; // ignore: prefer_initializing_formals

  final WordRepository _delegate;
  final String _secretWord;

  @override
  Future<List<String>> loadAllowedWords(int wordLength) =>
      _delegate.loadAllowedWords(wordLength);

  @override
  Future<List<String>> loadSecretWords(
    int wordLength,
    GameDifficulty difficulty,
  ) => _delegate.loadSecretWords(wordLength, difficulty);

  @override
  Future<bool> isAllowed(String word, int wordLength) =>
      _delegate.isAllowed(word, wordLength);

  @override
  Future<String> selectSecretWord(
    int wordLength,
    GameDifficulty difficulty,
  ) async => _secretWord;
}
