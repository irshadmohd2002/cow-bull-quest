import 'dart:math';

import 'package:cowbullgame/features/game/data/asset_word_repository.dart';
import 'package:cowbullgame/features/game/data/word_list_parser.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every asset path requested and serves canned contents, so tests
/// never need real Flutter assets or a mocking package.
class _FakeAssetLoader {
  _FakeAssetLoader(this._contents);

  final Map<String, String> _contents;
  final List<String> requestedPaths = [];

  Future<String> call(String assetPath) async {
    requestedPaths.add(assetPath);
    final contents = _contents[assetPath];
    if (contents == null) {
      throw StateError('no fake asset registered for $assetPath');
    }
    return contents;
  }

  int requestCountFor(String assetPath) =>
      requestedPaths.where((p) => p == assetPath).length;
}

/// An asset loader that always fails, to test [WordListLoadException].
class _ThrowingAssetLoader {
  Future<String> call(String assetPath) async {
    throw StateError('simulated asset-loading failure for $assetPath');
  }
}

/// A [Random] whose next index is always [index], so tests can assert
/// exactly which word gets selected.
class _FixedRandom implements Random {
  _FixedRandom(this.index);

  final int index;

  @override
  int nextInt(int max) => index;

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}

void main() {
  const allowed5Path = 'assets/generated/allowed_words_5.txt';
  const allowed4Path = 'assets/generated/allowed_words_4.txt';
  const allowed6Path = 'assets/generated/allowed_words_6.txt';

  String secretPath(int length, GameDifficulty difficulty) =>
      'assets/generated/secret_words_${difficulty.name}_$length.txt';

  _FakeAssetLoader defaultLoader() => _FakeAssetLoader({
    allowed5Path: 'apple\nbread\ncrane\nswift\nzesty\n',
    secretPath(5, GameDifficulty.easy): 'apple\n',
    secretPath(5, GameDifficulty.common): 'bread\ncrane\n',
    secretPath(5, GameDifficulty.hard): 'swift\n',
    allowed4Path: 'lace\nrace\ntace\nvace\n',
    secretPath(4, GameDifficulty.easy): 'lace\n',
    secretPath(4, GameDifficulty.common): 'race\n',
    secretPath(4, GameDifficulty.hard): 'tace\n',
    allowed6Path: 'garden\nmarble\nplanet\nturtle\n',
    secretPath(6, GameDifficulty.easy): 'garden\n',
    secretPath(6, GameDifficulty.common): 'marble\n',
    secretPath(6, GameDifficulty.hard): 'planet\n',
  });

  group('AssetWordRepository asset paths', () {
    test('requests the correct allowed-word asset path per length', () async {
      final loader = defaultLoader();
      final repo = AssetWordRepository(assetLoader: loader.call);
      await repo.loadAllowedWords(4);
      await repo.loadAllowedWords(5);
      await repo.loadAllowedWords(6);
      expect(
        loader.requestedPaths,
        containsAll([allowed4Path, allowed5Path, allowed6Path]),
      );
    });

    test('requests the correct secret-word asset path for every length/'
        'difficulty pair', () async {
      final loader = defaultLoader();
      final repo = AssetWordRepository(assetLoader: loader.call);
      for (final length in WordRepository.supportedLengths) {
        for (final difficulty in GameDifficulty.values) {
          await repo.loadSecretWords(length, difficulty);
        }
      }
      for (final length in WordRepository.supportedLengths) {
        for (final difficulty in GameDifficulty.values) {
          expect(
            loader.requestedPaths,
            contains(secretPath(length, difficulty)),
          );
        }
      }
    });
  });

  group('AssetWordRepository loading', () {
    test('loads and parses the allowed-word list', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      final words = await repo.loadAllowedWords(5);
      expect(words, ['apple', 'bread', 'crane', 'swift', 'zesty']);
    });

    test(
      'loads and parses the secret-word list for a given difficulty',
      () async {
        final repo = AssetWordRepository(assetLoader: defaultLoader().call);
        final words = await repo.loadSecretWords(5, GameDifficulty.common);
        expect(words, ['bread', 'crane']);
      },
    );

    test('accepts every supported length for every difficulty', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      for (final length in WordRepository.supportedLengths) {
        await expectLater(repo.loadAllowedWords(length), completes);
        for (final difficulty in GameDifficulty.values) {
          await expectLater(
            repo.loadSecretWords(length, difficulty),
            completes,
          );
        }
      }
    });

    test('rejects an unsupported length', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      expect(
        () => repo.loadAllowedWords(3),
        throwsA(isA<UnsupportedWordLengthException>()),
      );
      expect(
        () => repo.loadSecretWords(7, GameDifficulty.easy),
        throwsA(isA<UnsupportedWordLengthException>()),
      );
      expect(
        () => repo.isAllowed('crane', 3),
        throwsA(isA<UnsupportedWordLengthException>()),
      );
      expect(
        () => repo.selectSecretWord(3, GameDifficulty.easy),
        throwsA(isA<UnsupportedWordLengthException>()),
      );
    });
  });

  group('AssetWordRepository membership lookup', () {
    test('normalizes the input before checking membership', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      expect(await repo.isAllowed('  CRANE  ', 5), isTrue);
    });

    test('returns true for a valid guess', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      expect(await repo.isAllowed('bread', 5), isTrue);
    });

    test('returns false for an invalid guess', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      expect(await repo.isAllowed('zzzzz', 5), isFalse);
    });

    test('membership lookup is unaffected by difficulty: it never loads a '
        'secret asset', () async {
      final loader = defaultLoader();
      final repo = AssetWordRepository(assetLoader: loader.call);
      expect(await repo.isAllowed('zesty', 5), isTrue);
      expect(loader.requestCountFor(secretPath(5, GameDifficulty.easy)), 0);
      expect(loader.requestCountFor(secretPath(5, GameDifficulty.common)), 0);
      expect(loader.requestCountFor(secretPath(5, GameDifficulty.hard)), 0);
    });
  });

  group('AssetWordRepository allowed-word membership cache', () {
    test(
      'loading allowed words then checking membership reuses that load',
      () async {
        final loader = defaultLoader();
        final repo = AssetWordRepository(assetLoader: loader.call);
        await repo.loadAllowedWords(5);
        expect(await repo.isAllowed('crane', 5), isTrue);
        expect(loader.requestCountFor(allowed5Path), 1);
      },
    );

    test(
      'checking membership before loading allowed words reuses that load',
      () async {
        final loader = defaultLoader();
        final repo = AssetWordRepository(assetLoader: loader.call);
        expect(await repo.isAllowed('crane', 5), isTrue);
        final words = await repo.loadAllowedWords(5);
        expect(words, ['apple', 'bread', 'crane', 'swift', 'zesty']);
        expect(loader.requestCountFor(allowed5Path), 1);
      },
    );

    test('repeated membership checks do not reload the asset', () async {
      final loader = defaultLoader();
      final repo = AssetWordRepository(assetLoader: loader.call);
      await repo.isAllowed('crane', 5);
      await repo.isAllowed('bread', 5);
      await repo.isAllowed('zzzzz', 5);
      expect(loader.requestCountFor(allowed5Path), 1);
    });

    test('loading secret words does not load the allowed asset or populate '
        'its membership cache', () async {
      final loader = defaultLoader();
      final repo = AssetWordRepository(assetLoader: loader.call);
      await repo.loadSecretWords(5, GameDifficulty.common);
      expect(loader.requestCountFor(allowed5Path), 0);

      // Membership lookups still work correctly afterwards, and trigger
      // exactly one allowed-word load of their own.
      expect(await repo.isAllowed('crane', 5), isTrue);
      expect(loader.requestCountFor(allowed5Path), 1);
    });
  });

  group('AssetWordRepository secret selection', () {
    test('selects only from the requested difficulty pool, never another '
        "difficulty's words", () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      expect(await repo.selectSecretWord(5, GameDifficulty.easy), 'apple');
      expect(await repo.selectSecretWord(5, GameDifficulty.hard), 'swift');
    });

    test('a fixed injected Random always selects the same index', () async {
      final repo = AssetWordRepository(
        assetLoader: defaultLoader().call,
        random: _FixedRandom(1),
      );
      expect(await repo.selectSecretWord(5, GameDifficulty.common), 'crane');
    });

    test(
      'the same seed produces the same selection across instances',
      () async {
        final repoA = AssetWordRepository(
          assetLoader: defaultLoader().call,
          random: Random(1234),
        );
        final repoB = AssetWordRepository(
          assetLoader: defaultLoader().call,
          random: Random(1234),
        );
        expect(
          await repoA.selectSecretWord(5, GameDifficulty.common),
          await repoB.selectSecretWord(5, GameDifficulty.common),
        );
      },
    );
  });

  group('AssetWordRepository content error handling', () {
    test('throws EmptyWordListException for an empty generated list', () async {
      final loader = _FakeAssetLoader({allowed5Path: ''});
      final repo = AssetWordRepository(assetLoader: loader.call);
      expect(
        () => repo.loadAllowedWords(5),
        throwsA(isA<EmptyWordListException>()),
      );
    });

    test(
      'throws EmptyWordListException for an empty difficulty pool',
      () async {
        final loader = _FakeAssetLoader({
          secretPath(5, GameDifficulty.hard): '',
        });
        final repo = AssetWordRepository(assetLoader: loader.call);
        expect(
          () => repo.loadSecretWords(5, GameDifficulty.hard),
          throwsA(isA<EmptyWordListException>()),
        );
      },
    );

    test(
      'throws WordListFormatException for malformed generated content',
      () async {
        final loader = _FakeAssetLoader({allowed5Path: 'crane\ncr4ne\n'});
        final repo = AssetWordRepository(assetLoader: loader.call);
        expect(
          () => repo.loadAllowedWords(5),
          throwsA(isA<WordListFormatException>()),
        );
      },
    );
  });

  group('AssetWordRepository asset-load failure handling', () {
    test('wraps a failing asset loader in WordListLoadException with the '
        'asset path as context, preserving the original cause', () async {
      final repo = AssetWordRepository(
        assetLoader: _ThrowingAssetLoader().call,
      );
      try {
        await repo.loadAllowedWords(5);
        fail('expected WordListLoadException');
      } on WordListLoadException catch (e) {
        expect(e.message, contains(allowed5Path));
        expect(e.cause, isA<StateError>());
      }
    });

    test(
      'does not wrap content-validation failures as WordListLoadException',
      () async {
        final loader = _FakeAssetLoader({allowed5Path: 'crane\ncr4ne\n'});
        final repo = AssetWordRepository(assetLoader: loader.call);
        expect(
          () => repo.loadAllowedWords(5),
          throwsA(
            allOf(
              isA<WordListFormatException>(),
              isNot(isA<WordListLoadException>()),
            ),
          ),
        );
      },
    );
  });

  group('AssetWordRepository caching', () {
    test('loads each asset at most once across repeated calls', () async {
      final loader = defaultLoader();
      final repo = AssetWordRepository(assetLoader: loader.call);
      await repo.loadAllowedWords(5);
      await repo.loadAllowedWords(5);
      await repo.loadAllowedWords(5);
      expect(loader.requestCountFor(allowed5Path), 1);
    });

    test('keeps allowed-word and secret-word caches separate', () async {
      final loader = defaultLoader();
      final repo = AssetWordRepository(assetLoader: loader.call);
      final allowed = await repo.loadAllowedWords(5);
      final secret = await repo.loadSecretWords(5, GameDifficulty.common);
      expect(allowed, isNot(equals(secret)));
      expect(loader.requestCountFor(allowed5Path), 1);
      expect(loader.requestCountFor(secretPath(5, GameDifficulty.common)), 1);
    });

    test(
      'caching for one length does not short-circuit another length',
      () async {
        final loader = defaultLoader();
        final repo = AssetWordRepository(assetLoader: loader.call);
        await repo.loadAllowedWords(4);
        await repo.loadAllowedWords(5);
        expect(loader.requestCountFor(allowed4Path), 1);
        expect(loader.requestCountFor(allowed5Path), 1);
      },
    );

    test('caching for one difficulty does not short-circuit another '
        'difficulty at the same length', () async {
      final loader = defaultLoader();
      final repo = AssetWordRepository(assetLoader: loader.call);
      await repo.loadSecretWords(5, GameDifficulty.easy);
      await repo.loadSecretWords(5, GameDifficulty.common);
      await repo.loadSecretWords(5, GameDifficulty.hard);
      expect(loader.requestCountFor(secretPath(5, GameDifficulty.easy)), 1);
      expect(loader.requestCountFor(secretPath(5, GameDifficulty.common)), 1);
      expect(loader.requestCountFor(secretPath(5, GameDifficulty.hard)), 1);
    });

    test('repeated requests for the same length/difficulty pair reuse the '
        'cached load', () async {
      final loader = defaultLoader();
      final repo = AssetWordRepository(assetLoader: loader.call);
      await repo.loadSecretWords(5, GameDifficulty.easy);
      await repo.loadSecretWords(5, GameDifficulty.easy);
      await repo.selectSecretWord(5, GameDifficulty.easy);
      expect(loader.requestCountFor(secretPath(5, GameDifficulty.easy)), 1);
    });

    test('callers cannot mutate the cached list', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      final words = await repo.loadAllowedWords(5);
      expect(() => words.add('extra'), throwsUnsupportedError);

      // A fresh load must be unaffected by any attempted mutation.
      final wordsAgain = await repo.loadAllowedWords(5);
      expect(wordsAgain, ['apple', 'bread', 'crane', 'swift', 'zesty']);
    });
  });
}
