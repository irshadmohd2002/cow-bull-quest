import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../core/exceptions.dart';
import 'word_list_parser.dart';
import 'word_repository.dart';

/// Thrown when a word length outside [WordRepository.supportedLengths] is
/// requested.
class UnsupportedWordLengthException extends AppException {
  UnsupportedWordLengthException(int wordLength)
    : super(
        'unsupported word length: $wordLength '
        '(supported: ${WordRepository.supportedLengths})',
      );
}

/// Thrown when a generated word-list asset parses successfully but
/// contains no words.
class EmptyWordListException extends AppException {
  const EmptyWordListException(super.message);
}

/// Thrown when the asset-loading call itself fails — e.g. the asset is
/// missing from the bundle, or a fake loader throws in tests — as
/// opposed to [WordListFormatException]/[EmptyWordListException], which
/// mean the asset loaded successfully but its *content* was invalid.
class WordListLoadException extends AppException {
  WordListLoadException(String assetPath, this.cause)
    : super('failed to load word list asset "$assetPath": $cause');

  /// The original error thrown by the asset loader.
  final Object cause;
}

/// Loads a text asset by path. Matches the signature of
/// `AssetBundle.loadString`, which is the production implementation; tests
/// inject a fake to avoid needing real Flutter assets or a mocking
/// package.
typedef AssetStringLoader = Future<String> Function(String assetPath);

/// [WordRepository] backed by the generated text assets under
/// `assets/generated/`. Never reads `assets/source/` at runtime.
///
/// Parsed lists are cached in memory per word length so each asset is read
/// and parsed at most once; the allowed-word and secret-word caches are
/// kept as separate maps so a length being cached for one never masks the
/// other. A third cache, [_allowedSetCache], holds a [Set] built from the
/// already-parsed allowed list purely to make [isAllowed] a Set lookup
/// instead of a linear scan — it never performs its own asset load; it
/// always goes through (and therefore shares the cache of)
/// [loadAllowedWords]. Cached lists come from [WordListParser], which
/// returns unmodifiable lists, so callers can never mutate them; the
/// membership set is likewise never exposed outside this class.
class AssetWordRepository implements WordRepository {
  AssetWordRepository({AssetStringLoader? assetLoader, Random? random})
    : _loadAssetString = assetLoader ?? rootBundle.loadString,
      _random = random ?? Random();

  /// Convenience constructor for the production [AssetBundle].
  factory AssetWordRepository.fromBundle(
    AssetBundle bundle, {
    Random? random,
  }) => AssetWordRepository(assetLoader: bundle.loadString, random: random);

  static const String _generatedAssetDir = 'assets/generated';
  static const WordListParser _parser = WordListParser();

  final AssetStringLoader _loadAssetString;
  final Random _random;

  final Map<int, List<String>> _allowedCache = {};
  final Map<int, List<String>> _secretCache = {};
  final Map<int, Set<String>> _allowedSetCache = {};

  @override
  Future<List<String>> loadAllowedWords(int wordLength) => _loadCached(
    cache: _allowedCache,
    wordLength: wordLength,
    assetPath: _allowedAssetPath(wordLength),
    kind: 'allowed',
  );

  @override
  Future<List<String>> loadSecretWords(int wordLength) => _loadCached(
    cache: _secretCache,
    wordLength: wordLength,
    assetPath: _secretAssetPath(wordLength),
    kind: 'secret',
  );

  @override
  Future<bool> isAllowed(String word, int wordLength) async {
    final allowedSet = await _loadAllowedSet(wordLength);
    return allowedSet.contains(_normalize(word));
  }

  @override
  Future<String> selectSecretWord(int wordLength) async {
    final secrets = await loadSecretWords(wordLength);
    return secrets[_random.nextInt(secrets.length)];
  }

  /// Returns the membership [Set] for [wordLength], building it from the
  /// (possibly already-cached) parsed allowed list on first use. Never
  /// reads the asset directly — it always calls [loadAllowedWords], so an
  /// allowed-word asset is loaded at most once no matter which of
  /// [loadAllowedWords] or [isAllowed] is called first.
  Future<Set<String>> _loadAllowedSet(int wordLength) async {
    final cached = _allowedSetCache[wordLength];
    if (cached != null) return cached;
    final words = await loadAllowedWords(wordLength);
    final set = Set.unmodifiable(words);
    _allowedSetCache[wordLength] = set;
    return set;
  }

  Future<List<String>> _loadCached({
    required Map<int, List<String>> cache,
    required int wordLength,
    required String assetPath,
    required String kind,
  }) async {
    _validateSupportedLength(wordLength);
    final cached = cache[wordLength];
    if (cached != null) return cached;

    final String contents;
    try {
      contents = await _loadAssetString(assetPath);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        WordListLoadException(assetPath, error),
        stackTrace,
      );
    }

    final words = _parser.parse(
      contents,
      wordLength: wordLength,
      source: assetPath,
    );
    if (words.isEmpty) {
      throw EmptyWordListException('$kind word list at $assetPath is empty');
    }
    cache[wordLength] = words;
    return words;
  }

  static String _allowedAssetPath(int wordLength) =>
      '$_generatedAssetDir/allowed_words_$wordLength.txt';

  static String _secretAssetPath(int wordLength) =>
      '$_generatedAssetDir/secret_words_$wordLength.txt';

  static void _validateSupportedLength(int wordLength) {
    if (!WordRepository.supportedLengths.contains(wordLength)) {
      throw UnsupportedWordLengthException(wordLength);
    }
  }

  static String _normalize(String word) => word.trim().toLowerCase();
}
