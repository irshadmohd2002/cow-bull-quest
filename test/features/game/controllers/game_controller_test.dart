import 'dart:async';

import 'package:cowbullgame/coin_wallet.dart';
import 'package:cowbullgame/features/game/controllers/game_controller.dart';
import 'package:cowbullgame/features/game/controllers/game_controller_state.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:cowbullgame/features/game/models/game_config.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:cowbullgame/features/game/models/game_session.dart';
import 'package:cowbullgame/features/game/models/game_status.dart';
import 'package:cowbullgame/features/game/models/revealed_hint.dart';
import 'package:cowbullgame/features/game/services/game_engine.dart';
import 'package:cowbullgame/features/game/services/guess_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_completion_id_generator.dart';
import '../../../support/fake_game_feedback.dart';

/// A minimal [WordRepository] fake: [selectSecretWord] resolves from
/// [wordsByLengthAndDifficulty] by default, throws [errorToThrow] if set,
/// or — in [manualCompletion] mode — returns a pending [Completer]'s
/// future that the test resolves explicitly via [completeCall], to control
/// the order in which concurrent [GameController.startGame] calls resolve.
class _FakeWordRepository implements WordRepository {
  final Map<(int, GameDifficulty), String> wordsByLengthAndDifficulty = {};
  final List<(int, GameDifficulty)> requestedSelections = [];
  final List<Completer<String>> _completers = [];
  bool manualCompletion = false;
  Object? errorToThrow;

  /// The [StackTrace] most recently thrown alongside [errorToThrow], so
  /// tests can assert it was preserved end-to-end.
  StackTrace? lastThrownStackTrace;

  /// Words [loadAllowedWords] returns, keyed by word length. Seeded with
  /// every real guess literal this file submits via [submitGuess] so tests
  /// that don't care about dictionary validation don't need to register
  /// anything themselves; tests exercising rejection use a word (e.g.
  /// `qzxj`) deliberately absent from this set.
  final Map<int, Set<String>> allowedWordsByLength = {
    4: {'lace', 'race', 'mace', 'mock', 'tace'},
  };

  /// Convenience: registers [word] for [wordLength] under every
  /// [GameDifficulty], for tests that don't care which difficulty is used.
  /// Also adds [word] to [allowedWordsByLength], matching the real
  /// `WordRepository` invariant that every secret word is itself a member
  /// of its length's allowed-guess dictionary.
  void registerWordForAllDifficulties(int wordLength, String word) {
    for (final difficulty in GameDifficulty.values) {
      wordsByLengthAndDifficulty[(wordLength, difficulty)] = word;
    }
    allowedWordsByLength.putIfAbsent(wordLength, () => {}).add(word);
  }

  @override
  Future<String> selectSecretWord(int wordLength, GameDifficulty difficulty) {
    requestedSelections.add((wordLength, difficulty));
    final error = errorToThrow;
    if (error != null) {
      final stackTrace = StackTrace.current;
      lastThrownStackTrace = stackTrace;
      return Future.error(error, stackTrace);
    }
    if (manualCompletion) {
      final completer = Completer<String>();
      _completers.add(completer);
      return completer.future;
    }
    final word = wordsByLengthAndDifficulty[(wordLength, difficulty)];
    if (word == null) {
      throw StateError(
        'no fake secret word registered for length $wordLength, '
        'difficulty $difficulty',
      );
    }
    return Future.value(word);
  }

  /// Completes the [callIndex]-th call to [selectSecretWord] (0-based, in
  /// call order) with [word]. Only valid in [manualCompletion] mode.
  void completeCall(int callIndex, String word) {
    _completers[callIndex].complete(word);
  }

  @override
  Future<List<String>> loadAllowedWords(int wordLength) async =>
      List.unmodifiable(allowedWordsByLength[wordLength] ?? const <String>{});

  @override
  Future<List<String>> loadSecretWords(
    int wordLength,
    GameDifficulty difficulty,
  ) async => const [];

  @override
  Future<bool> isAllowed(String word, int wordLength) async => true;
}

void main() {
  const engine = GameEngine();
  final config4 = GameConfig.forSelection(
    wordLength: 4,
    difficulty: GameDifficulty.easy,
  );
  final config5 = GameConfig.forSelection(
    wordLength: 5,
    difficulty: GameDifficulty.easy,
  );
  final config6 = GameConfig.forSelection(
    wordLength: 6,
    difficulty: GameDifficulty.easy,
  );

  group('GameController initial state', () {
    test('starts idle', () {
      final controller = GameController(
        wordRepository: _FakeWordRepository(),
        gameEngine: engine,
      );
      expect(controller.state, isA<GameIdle>());
    });
  });

  group('GameController.startGame', () {
    test('emits loading immediately, then active once resolved', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      final future = controller.startGame(config4);
      expect(controller.state, isA<GameLoading>());

      await future;
      expect(controller.state, isA<GameActive>());
    });

    test('requests the secret word for the configured word length', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(6, 'garden');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await controller.startGame(config6);
      expect(repo.requestedSelections, [(6, GameDifficulty.easy)]);
    });

    test('requests the secret word for the configured difficulty', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(6, 'garden');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await controller.startGame(
        GameConfig.forSelection(wordLength: 6, difficulty: GameDifficulty.hard),
      );
      expect(repo.requestedSelections, [(6, GameDifficulty.hard)]);
    });

    test('the started session uses the config attempt limit', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(6, 'garden');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await controller.startGame(config6);
      final active = controller.state as GameActive;
      expect(active.view.wordLength, 6);
      expect(active.view.maxAttempts, 20);
      expect(active.view.attemptsUsed, 0);
      expect(active.view.attemptsRemaining, 20);
      expect(active.view.status, GameStatus.inProgress);
    });

    test('a repository failure becomes a typed GameStartupFailure', () async {
      final repo = _FakeWordRepository()
        ..errorToThrow = StateError('asset missing');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await controller.startGame(config4);
      final failure = controller.state as GameStartupFailure;
      expect(failure.error, isA<StateError>());
      expect(failure.config, config4);
    });

    test(
      'a repository failure preserves the original error and stack trace',
      () async {
        final error = StateError('asset missing');
        final repo = _FakeWordRepository()..errorToThrow = error;
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );

        await controller.startGame(config4);
        final failure = controller.state as GameStartupFailure;
        expect(identical(failure.error, error), isTrue);
        expect(
          identical(failure.stackTrace, repo.lastThrownStackTrace),
          isTrue,
        );
      },
    );

    test('a failed startup leaves no stale session behind', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      expect(controller.debugHasSession, isTrue);

      repo.errorToThrow = StateError('boom');
      await controller.startGame(config4);
      expect(controller.state, isA<GameStartupFailure>());
      expect(controller.debugHasSession, isFalse);
    });

    test('starting with a new configuration changes word length and attempt '
        'limit', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace')
        ..registerWordForAllDifficulties(5, 'crane');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await controller.startGame(config4);
      await controller.startGame(config5);

      final active = controller.state as GameActive;
      expect(active.view.wordLength, 5);
      expect(active.view.maxAttempts, 15);
    });

    test('starting with a new configuration replaces both word length and '
        'difficulty, requesting the new pool', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace')
        ..registerWordForAllDifficulties(5, 'crane');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.easy),
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 5, difficulty: GameDifficulty.hard),
      );

      expect(repo.requestedSelections, [
        (4, GameDifficulty.easy),
        (5, GameDifficulty.hard),
      ]);
    });

    test('stale asynchronous result cannot overwrite a newer start', () async {
      final repo = _FakeWordRepository()..manualCompletion = true;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      final futureA = controller.startGame(config4);
      final futureB = controller.startGame(config5);
      expect(repo.requestedSelections, [
        (4, GameDifficulty.easy),
        (5, GameDifficulty.easy),
      ]);

      // B (the newer request) resolves first.
      repo.completeCall(1, 'grape');
      await futureB;
      expect((controller.state as GameActive).view.wordLength, 5);

      // A (the stale request) resolves after B and must not overwrite it.
      repo.completeCall(0, 'lace');
      await futureA;
      expect((controller.state as GameActive).view.wordLength, 5);
      expect((controller.state as GameActive).view.maxAttempts, 15);
    });

    test(
      'a stale failing request does not overwrite a newer active game',
      () async {
        final repo = _FakeWordRepository()..manualCompletion = true;
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );

        final futureA = controller.startGame(config4);
        final futureB = controller.startGame(config5);

        repo.completeCall(1, 'crane');
        await futureB;

        repo._completers[0].completeError(StateError('too late'));
        await futureA;

        expect(controller.state, isA<GameActive>());
        expect((controller.state as GameActive).view.wordLength, 5);
      },
    );

    test('a stale request for a different difficulty at the same word length '
        'cannot overwrite a newer active game', () async {
      final repo = _FakeWordRepository()..manualCompletion = true;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      final easyConfig = GameConfig.forSelection(
        wordLength: 4,
        difficulty: GameDifficulty.easy,
      );
      final hardConfig = GameConfig.forSelection(
        wordLength: 4,
        difficulty: GameDifficulty.hard,
      );

      final futureA = controller.startGame(easyConfig);
      final futureB = controller.startGame(hardConfig);
      expect(repo.requestedSelections, [
        (4, GameDifficulty.easy),
        (4, GameDifficulty.hard),
      ]);

      // B (the newer request, hard) resolves first.
      repo.completeCall(1, 'tace');
      await futureB;

      // A (the stale, easy request) resolves after B and must not
      // overwrite it.
      repo.completeCall(0, 'lace');
      await futureA;

      // The active session is still the one started from the hard
      // config's word ("tace"), not the stale easy config's ("lace") —
      // confirmed indirectly via a winning guess, since the active view
      // never exposes the secret word directly.
      controller.submitGuess('tace');
      expect((controller.state as GameCompleted).session.secretWord, 'tace');
    });
  });

  group('GameController.restart', () {
    test('requests a new secret word for the same configuration', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await controller.startGame(config4);
      expect(repo.requestedSelections, [(4, GameDifficulty.easy)]);

      await controller.restart();
      expect(repo.requestedSelections, [
        (4, GameDifficulty.easy),
        (4, GameDifficulty.easy),
      ]);
      final active = controller.state as GameActive;
      expect(active.view.attemptsUsed, 0);
      expect(active.view.wordLength, 4);
    });

    test('restart preserves the difficulty from the most recent startGame '
        'call', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );
      await controller.restart();

      expect(repo.requestedSelections, [
        (4, GameDifficulty.hard),
        (4, GameDifficulty.hard),
      ]);
    });

    test('does nothing if no game has been started yet', () async {
      final controller = GameController(
        wordRepository: _FakeWordRepository(),
        gameEngine: engine,
      );
      await controller.restart();
      expect(controller.state, isA<GameIdle>());
    });
  });

  group('GameController.submitGuess while inactive', () {
    test('is safely ignored while idle', () {
      final controller = GameController(
        wordRepository: _FakeWordRepository(),
        gameEngine: engine,
      );
      expect(() => controller.submitGuess('lace'), returnsNormally);
      expect(controller.state, isA<GameIdle>());
    });

    test('is safely ignored while loading', () async {
      final repo = _FakeWordRepository()..manualCompletion = true;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      final future = controller.startGame(config4);
      expect(controller.state, isA<GameLoading>());

      expect(() => controller.submitGuess('lace'), returnsNormally);
      expect(controller.state, isA<GameLoading>());

      repo.completeCall(0, 'lace');
      await future;
    });

    test('is safely ignored after a startup failure', () async {
      final repo = _FakeWordRepository()..errorToThrow = StateError('boom');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      expect(controller.state, isA<GameStartupFailure>());

      expect(() => controller.submitGuess('lace'), returnsNormally);
      expect(controller.state, isA<GameStartupFailure>());
    });

    test('is safely ignored after the game has completed', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      controller.submitGuess('lace');
      expect(controller.state, isA<GameCompleted>());

      expect(() => controller.submitGuess('race'), returnsNormally);
      expect(controller.state, isA<GameCompleted>());
    });
  });

  group('GameController.submitGuess while active', () {
    test(
      'a valid guess updates the active state and consumes an attempt',
      () async {
        final repo = _FakeWordRepository()
          ..registerWordForAllDifficulties(4, 'lace');
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        await controller.startGame(config4);

        controller.submitGuess('race');
        final active = controller.state as GameActive;
        expect(active.view.attemptsUsed, 1);
        expect(active.view.attemptsRemaining, 9);
        expect(active.lastRejection, isNull);
      },
    );

    test('an invalid guess does not consume an attempt and exposes the typed '
        'reason', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      controller.submitGuess('toolong');
      final active = controller.state as GameActive;
      expect(active.view.attemptsUsed, 0);
      expect(active.view.attemptsRemaining, 10);
      expect(active.lastRejection, GuessValidationFailure.incorrectLength);
    });

    test('an accepted guess clears stale rejection feedback', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      controller.submitGuess('toolong');
      expect((controller.state as GameActive).lastRejection, isNotNull);

      controller.submitGuess('race');
      expect((controller.state as GameActive).lastRejection, isNull);
    });

    test('a winning guess transitions to completed/won', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      controller.submitGuess('lace');
      final completed = controller.state as GameCompleted;
      expect(completed.session.status, GameStatus.won);
    });

    test('a losing final guess transitions to completed/lost', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      for (var i = 0; i < 9; i++) {
        controller.submitGuess('race');
      }
      expect((controller.state as GameActive).view.attemptsRemaining, 1);

      controller.submitGuess('mace');
      final completed = controller.state as GameCompleted;
      expect(completed.session.status, GameStatus.lost);
    });
  });

  group('GameController dictionary validation', () {
    test('a guess absent from the allowed-guess dictionary is rejected as '
        'notInDictionary, without hard-coding any specific word', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      // 'qzxj' is alphabetic and exactly 4 letters, so it clears every
      // format check and is rejected purely for dictionary absence — it
      // is deliberately absent from the fake repository's allowed words.
      controller.submitGuess('qzxj');

      final active = controller.state as GameActive;
      expect(active.lastRejection, GuessValidationFailure.notInDictionary);
    });

    test('a dictionary-rejected guess does not consume an attempt', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      controller.submitGuess('qzxj');

      final active = controller.state as GameActive;
      expect(active.view.attemptsUsed, 0);
      expect(active.view.attemptsRemaining, 10);
    });

    test('a dictionary-rejected guess is not added to guess history', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      controller.submitGuess('qzxj');

      final active = controller.state as GameActive;
      expect(active.view.guesses, isEmpty);
    });

    test('an alphabetic, correct-length guess not in the dictionary is still '
        'rejected even when every letter individually is valid', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      controller.submitGuess('abcd');

      final active = controller.state as GameActive;
      expect(active.lastRejection, GuessValidationFailure.notInDictionary);
      expect(active.view.attemptsUsed, 0);
      expect(active.view.guesses, isEmpty);
    });

    test('a guess present in the allowed-guess dictionary is accepted and '
        'consumes an attempt', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      controller.submitGuess('race');

      final active = controller.state as GameActive;
      expect(active.lastRejection, isNull);
      expect(active.view.attemptsUsed, 1);
      expect(active.view.guesses, hasLength(1));
    });

    test('two consecutive valid dictionary words are both accepted', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      controller.submitGuess('race');
      controller.submitGuess('mace');

      final active = controller.state as GameActive;
      expect(active.lastRejection, isNull);
      expect(active.view.attemptsUsed, 2);
      expect(active.view.guesses, hasLength(2));
    });

    test('the controller passes the repository-loaded allowed-word set through '
        'to validation, not a hard-coded list', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace')
        ..allowedWordsByLength[4] = {'lace', 'zzzz'};
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      // 'race' is a real word but was excluded from this repository's
      // allowed set, so it must be rejected even though it would be
      // accepted with the default fake configuration.
      controller.submitGuess('race');
      expect(
        (controller.state as GameActive).lastRejection,
        GuessValidationFailure.notInDictionary,
      );

      // 'zzzz' was explicitly included, despite not being a real word —
      // proving the controller defers entirely to the repository's data.
      controller.submitGuess('zzzz');
      expect((controller.state as GameActive).lastRejection, isNull);
    });
  });

  group('GameController listeners', () {
    test('are notified for meaningful state changes', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.startGame(config4);
      expect(notifyCount, 2); // loading, then active

      controller.submitGuess('race');
      expect(notifyCount, 3);
    });
  });

  group('GameController disposal', () {
    test(
      'does not throw when a pending start resolves after dispose',
      () async {
        final repo = _FakeWordRepository()..manualCompletion = true;
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        final future = controller.startGame(config4);

        controller.dispose();
        repo.completeCall(0, 'lace');

        await expectLater(future, completes);
      },
    );

    test('submitGuess after dispose does not throw', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      controller.dispose();

      expect(() => controller.submitGuess('race'), returnsNormally);
    });

    test('startGame after disposal does not call the repository', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      controller.dispose();

      await controller.startGame(config4);
      expect(repo.requestedSelections, isEmpty);
      expect(controller.state, isA<GameIdle>());
    });

    test('restart after disposal does not call the repository', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      expect(repo.requestedSelections, [(4, GameDifficulty.easy)]);

      controller.dispose();
      await controller.restart();
      expect(repo.requestedSelections, [(4, GameDifficulty.easy)]);
    });

    test(
      'submitGuess after disposal does not change observable state',
      () async {
        final repo = _FakeWordRepository()
          ..registerWordForAllDifficulties(4, 'lace');
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        await controller.startGame(config4);
        final stateBefore = controller.state;

        controller.dispose();
        controller.submitGuess('race');

        expect(identical(controller.state, stateBefore), isTrue);
      },
    );

    test(
      'an in-flight successful startup cannot mutate state after disposal',
      () async {
        final repo = _FakeWordRepository()..manualCompletion = true;
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        final future = controller.startGame(config4);
        final stateBefore = controller.state;

        controller.dispose();
        repo.completeCall(0, 'lace');
        await future;

        expect(identical(controller.state, stateBefore), isTrue);
        expect(controller.debugHasSession, isFalse);
      },
    );

    test(
      'an in-flight failed startup cannot mutate state after disposal',
      () async {
        final repo = _FakeWordRepository()..manualCompletion = true;
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        final future = controller.startGame(config4);
        final stateBefore = controller.state;

        controller.dispose();
        repo._completers[0].completeError(StateError('too late'));
        await future;

        expect(identical(controller.state, stateBefore), isTrue);
        expect(controller.debugHasSession, isFalse);
      },
    );

    test('listeners are never notified after disposal', () async {
      final repo = _FakeWordRepository()..manualCompletion = true;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      final future = controller.startGame(config4);
      expect(notifyCount, 1); // GameLoading

      controller.dispose();
      repo.completeCall(0, 'lace');
      await future;

      expect(notifyCount, 1);
    });
  });

  group('GameController secret-word protection', () {
    test('active presentation state does not expose the secret word', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      final dynamic view = (controller.state as GameActive).view;
      expect(() => view.secretWord, throwsNoSuchMethodError);
    });

    test('completed state reveals the secret word deliberately', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      controller.submitGuess('lace');
      final completed = controller.state as GameCompleted;
      expect(completed.session.secretWord, 'lace');
    });
  });

  group('GameController.onGameCompleted', () {
    test('fires exactly once on a winning transition', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      var callCount = 0;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        onGameCompleted: (_, _) => callCount++,
      );
      await controller.startGame(config4);

      controller.submitGuess('lace');

      expect(callCount, 1);
    });

    test('fires exactly once on a losing transition', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      var callCount = 0;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        onGameCompleted: (_, _) => callCount++,
      );
      await controller.startGame(config4);

      for (var i = 0; i < 9; i++) {
        controller.submitGuess('race');
      }
      controller.submitGuess('mace');

      expect(callCount, 1);
    });

    test('receives the completed session with the final status', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      GameSession? completedSession;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        onGameCompleted: (_, session) => completedSession = session,
      );
      await controller.startGame(config4);

      controller.submitGuess('lace');

      expect(completedSession?.status, GameStatus.won);
      expect(completedSession?.secretWord, 'lace');
    });

    test('does not fire on a rejected guess', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      var callCount = 0;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        onGameCompleted: (_, _) => callCount++,
      );
      await controller.startGame(config4);

      controller.submitGuess('toolong');

      expect(callCount, 0);
    });

    test('does not fire again on a rebuild-style re-read of state', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      var callCount = 0;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        onGameCompleted: (_, _) => callCount++,
      );
      await controller.startGame(config4);
      controller.submitGuess('lace');
      expect(callCount, 1);

      // Reading state repeatedly, as a widget rebuild would, must not
      // re-fire the completion callback.
      // ignore: unnecessary_statements
      controller.state;
      // ignore: unnecessary_statements
      controller.state;

      expect(callCount, 1);
    });

    test('does not fire again for further submitGuess calls after '
        'completion', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      var callCount = 0;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        onGameCompleted: (_, _) => callCount++,
      );
      await controller.startGame(config4);
      controller.submitGuess('lace');
      expect(callCount, 1);

      controller.submitGuess('race');

      expect(callCount, 1);
    });

    test('does not fire for a failed startup', () async {
      final repo = _FakeWordRepository()..errorToThrow = StateError('boom');
      var callCount = 0;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        onGameCompleted: (_, _) => callCount++,
      );

      await controller.startGame(config4);

      expect(controller.state, isA<GameStartupFailure>());
      expect(callCount, 0);
    });

    test(
      'does not fire for an abandoned active game (disposed mid-game)',
      () async {
        final repo = _FakeWordRepository()
          ..registerWordForAllDifficulties(4, 'lace');
        var callCount = 0;
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
          onGameCompleted: (_, _) => callCount++,
        );
        await controller.startGame(config4);

        controller.dispose();

        expect(callCount, 0);
      },
    );

    test('restart allows a new, distinct completion event', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final completedSessions = <GameSession>[];
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        onGameCompleted: (_, session) => completedSessions.add(session),
      );
      await controller.startGame(config4);
      controller.submitGuess('lace');
      expect(completedSessions, hasLength(1));

      await controller.restart();
      controller.submitGuess('lace');

      expect(completedSessions, hasLength(2));
    });
  });

  group('GameController completion ID lifecycle', () {
    test('generates exactly one ID per successful start', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final generator = FakeCompletionIdGenerator(['id-1']);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        completionIdGenerator: generator,
      );

      await controller.startGame(config4);

      expect(generator.callCount, 1);
      expect(controller.debugActiveCompletionId, 'id-1');
    });

    test('a startup failure generates and retains no active ID', () async {
      final repo = _FakeWordRepository()..errorToThrow = StateError('boom');
      final generator = FakeCompletionIdGenerator(['id-1']);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        completionIdGenerator: generator,
      );

      await controller.startGame(config4);

      expect(generator.callCount, 0);
      expect(controller.debugActiveCompletionId, isNull);
    });

    test('a failed startup clears an ID retained from a previous successful '
        'game', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final generator = FakeCompletionIdGenerator(['id-1']);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        completionIdGenerator: generator,
      );
      await controller.startGame(config4);
      expect(controller.debugActiveCompletionId, 'id-1');

      repo.errorToThrow = StateError('boom');
      await controller.startGame(config4);

      expect(controller.state, isA<GameStartupFailure>());
      expect(controller.debugActiveCompletionId, isNull);
    });

    test('a stale start cannot replace the newer game ID', () async {
      final repo = _FakeWordRepository()..manualCompletion = true;
      // Only B's success ever reaches the generation-guarded generate()
      // call (A's later resolution is recognized as stale and returns
      // before calling it), so exactly one ID is ever generated here.
      final generator = FakeCompletionIdGenerator(['id-for-b']);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        completionIdGenerator: generator,
      );

      final futureA = controller.startGame(config4);
      final futureB = controller.startGame(config5);

      // B (the newer request) resolves first.
      repo.completeCall(1, 'grape');
      await futureB;
      expect(controller.debugActiveCompletionId, 'id-for-b');

      // A (the stale request) resolves after B and must not overwrite it.
      repo.completeCall(0, 'lace');
      await futureA;
      expect(controller.debugActiveCompletionId, 'id-for-b');
      expect(generator.callCount, 1);
    });

    test('completion uses the ID assigned at start', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final generator = FakeCompletionIdGenerator(['id-1']);
      String? receivedId;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        completionIdGenerator: generator,
        onGameCompleted: (id, _) => receivedId = id,
      );
      await controller.startGame(config4);

      controller.submitGuess('lace');

      expect(receivedId, 'id-1');
    });

    test(
      'invalid guesses and rebuild-style state reads do not alter the ID',
      () async {
        final repo = _FakeWordRepository()
          ..registerWordForAllDifficulties(4, 'lace');
        final generator = FakeCompletionIdGenerator(['id-1']);
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
          completionIdGenerator: generator,
        );
        await controller.startGame(config4);

        controller.submitGuess('toolong');
        // ignore: unnecessary_statements
        controller.state;
        // ignore: unnecessary_statements
        controller.state;

        expect(controller.debugActiveCompletionId, 'id-1');
        expect(generator.callCount, 1);
      },
    );

    test('restart uses a distinct injected ID', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final generator = FakeCompletionIdGenerator(['id-1', 'id-2']);
      final receivedIds = <String>[];
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        completionIdGenerator: generator,
        onGameCompleted: (id, _) => receivedIds.add(id),
      );
      await controller.startGame(config4);
      controller.submitGuess('lace');

      await controller.restart();
      controller.submitGuess('lace');

      expect(receivedIds, ['id-1', 'id-2']);
    });

    test('starting a different configuration generates a new ID', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace')
        ..registerWordForAllDifficulties(5, 'crane');
      final generator = FakeCompletionIdGenerator(['id-1', 'id-2']);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        completionIdGenerator: generator,
      );

      await controller.startGame(config4);
      expect(controller.debugActiveCompletionId, 'id-1');

      await controller.startGame(config5);
      expect(controller.debugActiveCompletionId, 'id-2');
    });

    test('disposal prevents a pending start from mutating the ID', () async {
      final repo = _FakeWordRepository()..manualCompletion = true;
      final generator = FakeCompletionIdGenerator(['id-1']);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        completionIdGenerator: generator,
      );
      final future = controller.startGame(config4);

      controller.dispose();
      repo.completeCall(0, 'lace');
      await future;

      expect(controller.debugActiveCompletionId, isNull);
      expect(generator.callCount, 0);
    });

    test('two different games deliberately share one ID only when the '
        'injected generator itself returns the same value', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final generator = FakeCompletionIdGenerator.constant('same-id');
      final receivedIds = <String>[];
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        completionIdGenerator: generator,
        onGameCompleted: (id, _) => receivedIds.add(id),
      );
      await controller.startGame(config4);
      controller.submitGuess('lace');

      await controller.restart();
      controller.submitGuess('lace');

      // GameController itself never deduplicates or caches IDs — it
      // simply calls generate() once per successful start. Reusing the
      // same value across two distinct games here is entirely the fake
      // generator's deliberate choice, not GameController behavior.
      expect(receivedIds, ['same-id', 'same-id']);
      expect(generator.callCount, 2);
    });
  });

  group('GameController history immutability', () {
    test('the active view exposes an unmodifiable guess list', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      controller.submitGuess('race');

      final active = controller.state as GameActive;
      expect(() => active.view.guesses.clear(), throwsUnsupportedError);
    });

    test('the completed session exposes an unmodifiable guess list', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      controller.submitGuess('lace');

      final completed = controller.state as GameCompleted;
      expect(() => completed.session.guesses.clear(), throwsUnsupportedError);
    });
  });

  group('GameController hint availability', () {
    test('is null when no game is active', () {
      final controller = GameController(
        wordRepository: _FakeWordRepository(),
        gameEngine: engine,
      );
      expect(controller.hintAvailability, isNull);
    });

    test('Easy allows exactly one hint costing 20 coins', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.easy),
      );

      final availability = controller.hintAvailability!;
      expect(availability.canRequestHint, isTrue);
      expect(availability.maxHints, 1);
      expect(availability.hintsUsed, 0);
      expect(availability.nextHintCost, 20);
    });

    test('Medium allows exactly one hint costing 20 coins', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(
        GameConfig.forSelection(
          wordLength: 4,
          difficulty: GameDifficulty.common,
        ),
      );

      final availability = controller.hintAvailability!;
      expect(availability.maxHints, 1);
      expect(availability.nextHintCost, 20);
    });

    test('Hard allows two hints; the first is free', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );

      final availability = controller.hintAvailability!;
      expect(availability.maxHints, 2);
      expect(availability.nextHintCost, 0);
    });

    test('is null once the game is won', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      controller.submitGuess('lace');

      expect(controller.hintAvailability, isNull);
    });
  });

  group('GameController.useHint on Easy/Medium', () {
    test('a successful hint deducts exactly 20 coins and reveals the '
        'lowest unrevealed position', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.easy),
      );

      final outcome = controller.useHint();

      expect(outcome, isA<HintRevealed>());
      final revealed = outcome as HintRevealed;
      expect(revealed.coinsSpent, 20);
      expect(revealed.hint, const RevealedHint(position: 0, letter: 'l'));
      expect(wallet.balance, 80);
    });

    test('a second hint is blocked without deduction once the one-hint '
        'limit is reached', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(
          wordLength: 4,
          difficulty: GameDifficulty.common,
        ),
      );

      controller.useHint();
      final second = controller.useHint();

      expect(second, isA<HintNotRevealed>());
      expect(
        (second as HintNotRevealed).reason,
        HintUnavailableReason.limitReached,
      );
      expect(wallet.balance, 80);
    });

    test('an insufficient balance blocks the hint without deducting '
        'anything', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 10);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.easy),
      );

      final outcome = controller.useHint();

      expect(outcome, isA<HintNotRevealed>());
      expect(
        (outcome as HintNotRevealed).reason,
        HintUnavailableReason.insufficientCoins,
      );
      expect(wallet.balance, 10);
    });
  });

  group('GameController.useHint on Hard', () {
    test('the first hint is free and does not deduct coins', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );

      final outcome = controller.useHint();

      expect(outcome, isA<HintRevealed>());
      expect((outcome as HintRevealed).coinsSpent, 0);
      expect(wallet.balance, 100);
    });

    test('the second hint costs 20 coins and deducts them', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );

      controller.useHint(); // free
      final second = controller.useHint();

      expect(second, isA<HintRevealed>());
      expect((second as HintRevealed).coinsSpent, 20);
      expect(wallet.balance, 80);
    });

    test('a third hint is blocked without deduction', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );

      controller.useHint();
      controller.useHint();
      final third = controller.useHint();

      expect(third, isA<HintNotRevealed>());
      expect(
        (third as HintNotRevealed).reason,
        HintUnavailableReason.limitReached,
      );
      expect(wallet.balance, 80);
    });
  });

  group('GameController hint correctness', () {
    test(
      'a known Bull position from an accepted guess is not selected',
      () async {
        final repo = _FakeWordRepository()
          ..registerWordForAllDifficulties(4, 'lace');
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        await controller.startGame(
          GameConfig.forSelection(
            wordLength: 4,
            difficulty: GameDifficulty.hard,
          ),
        );

        // 'race' scores 3 bulls against 'lace' (positions 1, 2, 3) — only
        // position 0 remains unknown, so the hint must reveal that one.
        controller.submitGuess('race');
        final outcome = controller.useHint() as HintRevealed;

        expect(outcome.hint, const RevealedHint(position: 0, letter: 'l'));
      },
    );

    test(
      'a previously hinted position is not repeated by a later hint',
      () async {
        final repo = _FakeWordRepository()
          ..registerWordForAllDifficulties(4, 'lace');
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        await controller.startGame(
          GameConfig.forSelection(
            wordLength: 4,
            difficulty: GameDifficulty.hard,
          ),
        );

        final first = controller.useHint() as HintRevealed;
        final second = controller.useHint() as HintRevealed;

        expect(second.hint.position, isNot(first.hint.position));
      },
    );

    test('a hint does not change the attempt count or guess history', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );

      controller.useHint();

      final active = controller.state as GameActive;
      expect(active.view.attemptsUsed, 0);
      expect(active.view.guesses, isEmpty);
    });

    test('no deduction occurs when no useful hint is available', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );

      controller.useHint(); // free hint reveals position 0
      // 'race' scores 3 bulls (positions 1, 2, 3) — every position is now
      // known, even though Hard's hint limit (2) has not been reached.
      controller.submitGuess('race');
      final outcome = controller.useHint();

      expect(outcome, isA<HintNotRevealed>());
      expect(
        (outcome as HintNotRevealed).reason,
        HintUnavailableReason.noUsefulHintRemains,
      );
      expect(wallet.balance, 100);
    });

    test('hints are unavailable after a win', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );
      controller.submitGuess('lace');

      final outcome = controller.useHint();

      expect(outcome, isA<HintNotRevealed>());
      expect(
        (outcome as HintNotRevealed).reason,
        HintUnavailableReason.gameNotActive,
      );
      expect(wallet.balance, 100);
    });

    test('hints are unavailable after a loss', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );
      for (var i = 0; i < 9; i++) {
        controller.submitGuess('race');
      }
      controller.submitGuess('mace');
      expect(controller.state, isA<GameCompleted>());

      final outcome = controller.useHint();

      expect(outcome, isA<HintNotRevealed>());
      expect(
        (outcome as HintNotRevealed).reason,
        HintUnavailableReason.gameNotActive,
      );
      expect(wallet.balance, 100);
    });

    test('rapid repeated calls cannot deduct twice on a single-hint '
        'difficulty', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.easy),
      );

      controller.useHint();
      controller.useHint();
      controller.useHint();

      expect(wallet.balance, 80);
    });

    test('rapid repeated calls beyond Hard\'s two-hint limit deduct at '
        'most once', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );

      controller.useHint();
      controller.useHint();
      controller.useHint();
      controller.useHint();

      expect(wallet.balance, 80);
    });
  });

  group('GameController hint state lifecycle', () {
    test('hint usage resets when starting a new game', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      final easyConfig = GameConfig.forSelection(
        wordLength: 4,
        difficulty: GameDifficulty.easy,
      );
      await controller.startGame(easyConfig);
      controller.useHint();
      expect(controller.hintAvailability!.hintsUsed, 1);

      await controller.startGame(easyConfig);

      expect(controller.hintAvailability!.hintsUsed, 0);
    });

    test('restart creates a fresh game with fresh hint limits but does not '
        'refund coins already spent', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      final hardConfig = GameConfig.forSelection(
        wordLength: 4,
        difficulty: GameDifficulty.hard,
      );
      await controller.startGame(hardConfig);
      controller.useHint(); // free
      controller.useHint(); // paid, 20 coins
      expect(wallet.balance, 80);

      await controller.restart();

      expect(controller.hintAvailability!.hintsUsed, 0);
      expect(wallet.balance, 80);
    });
  });

  group('GameController coin wallet ownership', () {
    test('exposes the injected wallet via the coinWallet getter', () {
      final wallet = CoinWallet(initialBalance: 55);
      final controller = GameController(
        wordRepository: _FakeWordRepository(),
        gameEngine: engine,
        coinWallet: wallet,
      );

      expect(identical(controller.coinWallet, wallet), isTrue);
    });

    test('creates its own fallback wallet with the starting balance when '
        'none is injected', () {
      final controller = GameController(
        wordRepository: _FakeWordRepository(),
        gameEngine: engine,
      );

      expect(controller.coinWallet.balance, startingCoinBalance);
    });

    test('does not dispose an externally-injected wallet', () async {
      final wallet = CoinWallet(initialBalance: 100);
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      await controller.startGame(config4);

      controller.dispose();

      expect(wallet.spend(10), isTrue);
    });

    test('disposes its own fallback wallet on dispose', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      final wallet = controller.coinWallet;

      controller.dispose();

      expect(wallet.spend(10), isFalse);
    });
  });

  group('GameController GameFeedback events', () {
    test(
      'an accepted, still-in-progress guess reports onValidGuess once',
      (() async {
        final repo = _FakeWordRepository()
          ..registerWordForAllDifficulties(4, 'lace');
        final feedback = FakeGameFeedback();
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
          feedback: feedback,
        );
        await controller.startGame(config4);

        controller.submitGuess('race');

        expect(feedback.calls, ['onValidGuess']);
      }),
    );

    test('a rejected guess reports onInvalidGuess once', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        feedback: feedback,
      );
      await controller.startGame(config4);

      controller.submitGuess('qzxj');

      expect(feedback.calls, ['onInvalidGuess']);
    });

    test('a rejected guess does not consume an attempt', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        feedback: feedback,
      );
      await controller.startGame(config4);

      controller.submitGuess('qzxj');

      final active = controller.state as GameActive;
      expect(active.view.attemptsUsed, 0);
    });

    test('a winning guess reports onGameWon exactly once, with no '
        'onValidGuess call', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        feedback: feedback,
      );
      await controller.startGame(config4);

      controller.submitGuess('lace');

      expect(feedback.calls, ['onGameWon']);
    });

    test('a losing final guess reports onGameLost exactly once', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        feedback: feedback,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.easy),
      );
      // maxAttempts for Easy/4-letter is 10; exhaust every attempt with a
      // guess that is valid but never wins.
      for (var i = 0; i < 9; i++) {
        controller.submitGuess('race');
      }
      feedback.calls.clear();

      controller.submitGuess('race');

      expect(feedback.calls, ['onGameLost']);
    });

    test('rebuilding/reading the same completed state does not replay '
        'result feedback', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        feedback: feedback,
      );
      await controller.startGame(config4);
      controller.submitGuess('lace');
      expect(feedback.calls, ['onGameWon']);

      // Reading state repeatedly (as a rebuild would) triggers nothing more.
      // ignore: unnecessary_statements
      controller.state;
      // ignore: unnecessary_statements
      controller.state;
      expect(feedback.calls, ['onGameWon']);

      // A further submission against the now-completed game is a no-op.
      controller.submitGuess('race');
      expect(feedback.calls, ['onGameWon']);
    });

    test('restarting permits result feedback again in the new game', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        feedback: feedback,
      );
      await controller.startGame(config4);
      controller.submitGuess('lace');
      expect(feedback.calls, ['onGameWon']);

      await controller.restart();
      controller.submitGuess('lace');

      expect(feedback.calls, ['onGameWon', 'onGameWon']);
    });

    test('a free Hard hint reports onHintRevealed(paid: false)', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        feedback: feedback,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.hard),
      );

      controller.useHint();

      expect(feedback.calls, ['onHintRevealed(paid: false)']);
    });

    test('a paid hint reports onHintRevealed(paid: true) only after the '
        'coin deduction succeeds', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
        feedback: feedback,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.easy),
      );

      final outcome = controller.useHint();

      expect(outcome, isA<HintRevealed>());
      expect(wallet.balance, 80);
      expect(feedback.calls, ['onHintRevealed(paid: true)']);
    });

    test('an insufficient-balance hint attempt reports no feedback', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final wallet = CoinWallet(initialBalance: 10);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
        feedback: feedback,
      );
      await controller.startGame(
        GameConfig.forSelection(wordLength: 4, difficulty: GameDifficulty.easy),
      );

      controller.useHint();

      expect(feedback.calls, isEmpty);
    });

    test('a hint attempt once the limit is reached reports no further '
        'feedback', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        feedback: feedback,
      );
      await controller.startGame(
        GameConfig.forSelection(
          wordLength: 4,
          difficulty: GameDifficulty.common,
        ),
      );

      controller.useHint();
      feedback.calls.clear();
      controller.useHint();

      expect(feedback.calls, isEmpty);
    });

    test('rapid repeated submissions of the same guess each report their '
        'own outcome, never duplicated for one submission', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final feedback = FakeGameFeedback();
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        feedback: feedback,
      );
      await controller.startGame(config4);

      controller.submitGuess('race');
      controller.submitGuess('mace');

      expect(feedback.calls, ['onValidGuess', 'onValidGuess']);
    });

    test('the default feedback is a no-op and never throws', () async {
      final repo = _FakeWordRepository()
        ..registerWordForAllDifficulties(4, 'lace');
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      expect(() => controller.submitGuess('lace'), returnsNormally);
    });
  });
}
