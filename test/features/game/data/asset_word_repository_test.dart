import 'dart:math';

import 'package:cowbullgame/features/game/data/asset_word_repository.dart';
import 'package:cowbullgame/features/game/data/word_list_parser.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
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
  const secret5Path = 'assets/generated/secret_words_5.txt';
  const allowed4Path = 'assets/generated/allowed_words_4.txt';
  const secret4Path = 'assets/generated/secret_words_4.txt';
  const allowed6Path = 'assets/generated/allowed_words_6.txt';
  const secret6Path = 'assets/generated/secret_words_6.txt';

  _FakeAssetLoader defaultLoader() => _FakeAssetLoader({
    allowed5Path: 'apple\nbread\ncrane\nzesty\n',
    secret5Path: 'apple\nbread\ncrane\n',
    allowed4Path: 'lace\nrace\ntace\n',
    secret4Path: 'lace\nrace\n',
    allowed6Path: 'garden\nmarble\nplanet\n',
    secret6Path: 'garden\nmarble\n',
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

    test('requests the correct secret-word asset path per length', () async {
      final loader = defaultLoader();
      final repo = AssetWordRepository(assetLoader: loader.call);
      await repo.loadSecretWords(4);
      await repo.loadSecretWords(5);
      await repo.loadSecretWords(6);
      expect(
        loader.requestedPaths,
        containsAll([secret4Path, secret5Path, secret6Path]),
      );
    });
  });

  group('AssetWordRepository loading', () {
    test('loads and parses the allowed-word list', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      final words = await repo.loadAllowedWords(5);
      expect(words, ['apple', 'bread', 'crane', 'zesty']);
    });

    test('loads and parses the secret-word list', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      final words = await repo.loadSecretWords(5);
      expect(words, ['apple', 'bread', 'crane']);
    });

    test('accepts every supported length', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      for (final length in WordRepository.supportedLengths) {
        await expectLater(repo.loadAllowedWords(length), completes);
        await expectLater(repo.loadSecretWords(length), completes);
      }
    });

    test('rejects an unsupported length', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      expect(
        () => repo.loadAllowedWords(3),
        throwsA(isA<UnsupportedWordLengthException>()),
      );
      expect(
        () => repo.loadSecretWords(7),
        throwsA(isA<UnsupportedWordLengthException>()),
      );
      expect(
        () => repo.isAllowed('crane', 3),
        throwsA(isA<UnsupportedWordLengthException>()),
      );
      expect(
        () => repo.selectSecretWord(3),
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
        expect(words, ['apple', 'bread', 'crane', 'zesty']);
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
      await repo.loadSecretWords(5);
      expect(loader.requestCountFor(allowed5Path), 0);

      // Membership lookups still work correctly afterwards, and trigger
      // exactly one allowed-word load of their own.
      expect(await repo.isAllowed('crane', 5), isTrue);
      expect(loader.requestCountFor(allowed5Path), 1);
    });
  });

  group('AssetWordRepository secret selection', () {
    test(
      'selects only from the secret-word list, never allowed-only words',
      () async {
        // allowed_words_5 contains "zesty", which is not in secret_words_5.
        final secrets = await AssetWordRepository(
          assetLoader: defaultLoader().call,
        ).loadSecretWords(5);
        for (var i = 0; i < secrets.length; i++) {
          final picked = await AssetWordRepository(
            assetLoader: defaultLoader().call,
            random: _FixedRandom(i),
          ).selectSecretWord(5);
          expect(secrets, contains(picked));
          expect(picked, isNot('zesty'));
        }
      },
    );

    test('a fixed injected Random always selects the same index', () async {
      final repo = AssetWordRepository(
        assetLoader: defaultLoader().call,
        random: _FixedRandom(1),
      );
      expect(await repo.selectSecretWord(5), 'bread');
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
          await repoA.selectSecretWord(5),
          await repoB.selectSecretWord(5),
        );
      },
    );
  });

  group('AssetWordRepository content error handling', () {
    test('throws EmptyWordListException for an empty generated list', () async {
      final loader = _FakeAssetLoader({allowed5Path: '', secret5Path: ''});
      final repo = AssetWordRepository(assetLoader: loader.call);
      expect(
        () => repo.loadAllowedWords(5),
        throwsA(isA<EmptyWordListException>()),
      );
    });

    test(
      'throws WordListFormatException for malformed generated content',
      () async {
        final loader = _FakeAssetLoader({
          allowed5Path: 'crane\ncr4ne\n',
          secret5Path: 'crane\n',
        });
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
      final secret = await repo.loadSecretWords(5);
      expect(allowed, isNot(equals(secret)));
      expect(loader.requestCountFor(allowed5Path), 1);
      expect(loader.requestCountFor(secret5Path), 1);
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

    test('callers cannot mutate the cached list', () async {
      final repo = AssetWordRepository(assetLoader: defaultLoader().call);
      final words = await repo.loadAllowedWords(5);
      expect(() => words.add('extra'), throwsUnsupportedError);

      // A fresh load must be unaffected by any attempted mutation.
      final wordsAgain = await repo.loadAllowedWords(5);
      expect(wordsAgain, ['apple', 'bread', 'crane', 'zesty']);
    });
  });
}
