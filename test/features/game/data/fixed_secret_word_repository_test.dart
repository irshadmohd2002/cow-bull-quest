import 'package:cowbullgame/features/game/data/fixed_secret_word_repository.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_word_repository.dart';

void main() {
  group('FixedSecretWordRepository', () {
    test(
      'selectSecretWord always returns the fixed word, regardless of difficulty',
      () async {
        final delegate = FakeWordRepository();
        final repository = FixedSecretWordRepository(
          delegate: delegate,
          secretWord: 'lace',
        );

        for (final difficulty in GameDifficulty.values) {
          expect(await repository.selectSecretWord(4, difficulty), 'lace');
        }
      },
    );

    test('delegates loadAllowedWords to the wrapped repository', () async {
      final delegate = FakeWordRepository()
        ..registerAllowedWords(4, ['lace', 'race', 'mace']);
      final repository = FixedSecretWordRepository(
        delegate: delegate,
        secretWord: 'lace',
      );

      expect(
        await repository.loadAllowedWords(4),
        await delegate.loadAllowedWords(4),
      );
    });

    test(
      'delegates loadSecretWords to the wrapped repository unchanged',
      () async {
        final delegate = FakeWordRepository()
          ..registerSecretWords(4, GameDifficulty.common, ['acid', 'acts']);
        final repository = FixedSecretWordRepository(
          delegate: delegate,
          secretWord: 'acid',
        );

        expect(
          await repository.loadSecretWords(4, GameDifficulty.common),
          await delegate.loadSecretWords(4, GameDifficulty.common),
        );
      },
    );

    test('delegates isAllowed to the wrapped repository', () async {
      final delegate = FakeWordRepository()..registerAllowedWords(4, ['lace']);
      final repository = FixedSecretWordRepository(
        delegate: delegate,
        secretWord: 'lace',
      );

      expect(await repository.isAllowed('lace', 4), isTrue);
      expect(await repository.isAllowed('zzzz', 4), isFalse);
    });
  });
}
