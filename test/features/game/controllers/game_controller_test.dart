import 'dart:async';

import 'package:cowbullgame/features/game/controllers/game_controller.dart';
import 'package:cowbullgame/features/game/controllers/game_controller_state.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:cowbullgame/features/game/models/game_config.dart';
import 'package:cowbullgame/features/game/models/game_status.dart';
import 'package:cowbullgame/features/game/services/game_engine.dart';
import 'package:cowbullgame/features/game/services/guess_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [WordRepository] fake: [selectSecretWord] resolves from
/// [wordsByLength] by default, throws [errorToThrow] if set, or — in
/// [manualCompletion] mode — returns a pending [Completer]'s future that
/// the test resolves explicitly via [completeCall], to control the order in
/// which concurrent [GameController.startGame] calls resolve.
class _FakeWordRepository implements WordRepository {
  final Map<int, String> wordsByLength = {};
  final List<int> requestedLengths = [];
  final List<Completer<String>> _completers = [];
  bool manualCompletion = false;
  Object? errorToThrow;

  /// The [StackTrace] most recently thrown alongside [errorToThrow], so
  /// tests can assert it was preserved end-to-end.
  StackTrace? lastThrownStackTrace;

  @override
  Future<String> selectSecretWord(int wordLength) {
    requestedLengths.add(wordLength);
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
    final word = wordsByLength[wordLength];
    if (word == null) {
      throw StateError('no fake secret word registered for length $wordLength');
    }
    return Future.value(word);
  }

  /// Completes the [callIndex]-th call to [selectSecretWord] (0-based, in
  /// call order) with [word]. Only valid in [manualCompletion] mode.
  void completeCall(int callIndex, String word) {
    _completers[callIndex].complete(word);
  }

  @override
  Future<List<String>> loadAllowedWords(int wordLength) async => const [];

  @override
  Future<List<String>> loadSecretWords(int wordLength) async => const [];

  @override
  Future<bool> isAllowed(String word, int wordLength) async => true;
}

void main() {
  const engine = GameEngine();
  final config4 = GameConfig.forWordLength(4);
  final config5 = GameConfig.forWordLength(5);
  final config6 = GameConfig.forWordLength(6);

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
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
      final repo = _FakeWordRepository()..wordsByLength[6] = 'garden';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await controller.startGame(config6);
      expect(repo.requestedLengths, [6]);
    });

    test('the started session uses the config attempt limit', () async {
      final repo = _FakeWordRepository()..wordsByLength[6] = 'garden';
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
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
        ..wordsByLength[4] = 'lace'
        ..wordsByLength[5] = 'crane';
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

    test('stale asynchronous result cannot overwrite a newer start', () async {
      final repo = _FakeWordRepository()..manualCompletion = true;
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      final futureA = controller.startGame(config4);
      final futureB = controller.startGame(config5);
      expect(repo.requestedLengths, [4, 5]);

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
  });

  group('GameController.restart', () {
    test('requests a new secret word for the same configuration', () async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await controller.startGame(config4);
      expect(repo.requestedLengths, [4]);

      await controller.restart();
      expect(repo.requestedLengths, [4, 4]);
      final active = controller.state as GameActive;
      expect(active.view.attemptsUsed, 0);
      expect(active.view.wordLength, 4);
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
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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

  group('GameController listeners', () {
    test('are notified for meaningful state changes', () async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      controller.dispose();

      expect(() => controller.submitGuess('race'), returnsNormally);
    });

    test('startGame after disposal does not call the repository', () async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      controller.dispose();

      await controller.startGame(config4);
      expect(repo.requestedLengths, isEmpty);
      expect(controller.state, isA<GameIdle>());
    });

    test('restart after disposal does not call the repository', () async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);
      expect(repo.requestedLengths, [4]);

      controller.dispose();
      await controller.restart();
      expect(repo.requestedLengths, [4]);
    });

    test(
      'submitGuess after disposal does not change observable state',
      () async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      await controller.startGame(config4);

      final dynamic view = (controller.state as GameActive).view;
      expect(() => view.secretWord, throwsNoSuchMethodError);
    });

    test('completed state reveals the secret word deliberately', () async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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

  group('GameController history immutability', () {
    test('the active view exposes an unmodifiable guess list', () async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
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
}
