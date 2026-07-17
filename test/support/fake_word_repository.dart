import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';

/// Minimal, fully in-memory [WordRepository] fake for tests that don't need
/// asset loading, random selection, or failure injection — just enough to
/// exercise a `GameController`/`FixedSecretWordRepository` end to end with
/// deterministic, pre-registered words.
class FakeWordRepository implements WordRepository {
  FakeWordRepository({
    Map<int, List<String>>? allowedWords,
    Map<(int, GameDifficulty), List<String>>? secretWords,
  }) : _allowedWords = {...?allowedWords},
       _secretWords = {...?secretWords};

  final Map<int, List<String>> _allowedWords;
  final Map<(int, GameDifficulty), List<String>> _secretWords;

  void registerAllowedWords(int wordLength, List<String> words) {
    _allowedWords[wordLength] = [...?_allowedWords[wordLength], ...words];
  }

  void registerSecretWords(
    int wordLength,
    GameDifficulty difficulty,
    List<String> words,
  ) {
    final key = (wordLength, difficulty);
    _secretWords[key] = [...?_secretWords[key], ...words];
    registerAllowedWords(wordLength, words);
  }

  @override
  Future<List<String>> loadAllowedWords(int wordLength) async =>
      _allowedWords[wordLength] ?? const [];

  @override
  Future<List<String>> loadSecretWords(
    int wordLength,
    GameDifficulty difficulty,
  ) async => _secretWords[(wordLength, difficulty)] ?? const [];

  @override
  Future<bool> isAllowed(String word, int wordLength) async =>
      (_allowedWords[wordLength] ?? const []).contains(
        word.trim().toLowerCase(),
      );

  @override
  Future<String> selectSecretWord(
    int wordLength,
    GameDifficulty difficulty,
  ) async {
    final words = _secretWords[(wordLength, difficulty)] ?? const [];
    return words.first;
  }
}
