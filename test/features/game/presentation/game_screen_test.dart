import 'package:cowbullgame/features/game/controllers/game_controller.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:cowbullgame/features/game/models/game_config.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:cowbullgame/features/game/presentation/game_screen.dart';
import 'package:cowbullgame/features/game/services/game_engine.dart';
import 'package:cowbullgame/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [WordRepository] fake: resolves [selectSecretWord] from
/// [wordsByLength] (keyed by word length only — these widget tests never
/// exercise cross-difficulty behavior, which `game_controller_test.dart`
/// already covers), or throws [errorToThrow] if set.
class _FakeWordRepository implements WordRepository {
  final Map<int, String> wordsByLength = {};
  Object? errorToThrow;

  /// Words [loadAllowedWords] returns, keyed by word length. Seeded with
  /// every real guess literal this file submits through the UI, so tests
  /// that don't care about dictionary validation don't need to register
  /// anything themselves.
  final Map<int, Set<String>> allowedWordsByLength = {
    4: {'lace', 'race', 'mock'},
  };

  @override
  Future<String> selectSecretWord(
    int wordLength,
    GameDifficulty difficulty,
  ) async {
    final error = errorToThrow;
    if (error != null) throw error;
    final word = wordsByLength[wordLength];
    if (word == null) {
      throw StateError('no fake secret word registered for length $wordLength');
    }
    return word;
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

  Widget buildSubject(GameController controller, GameConfig config) {
    return MaterialApp(
      home: GameScreen(controller: controller, config: config),
    );
  }

  Future<void> enterAndSubmit(WidgetTester tester, String guess) async {
    await tester.enterText(find.byType(TextField), guess);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a loading indicator while starting the game', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('shows the active game once startup succeeds', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows word length and attempts', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    // Word length is shown in a rich-text status-panel chip.
    expect(find.textContaining('4', findRichText: true), findsWidgets);
    expect(find.textContaining('10'), findsWidgets); // max attempts for 4
  });

  testWidgets('the app bar title is exactly Cow Bull Quest, with no '
      'configuration suffix', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect((appBar.title as Text).data, 'Cow Bull Quest');
  });

  testWidgets('shows the selected difficulty in the status panel during '
      'active play', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);
    final hardConfig4 = GameConfig.forSelection(
      wordLength: 4,
      difficulty: GameDifficulty.hard,
    );

    await tester.pumpWidget(buildSubject(controller, hardConfig4));
    await tester.pumpAndSettle();

    // The status panel's difficulty chip renders as rich text.
    expect(
      find.textContaining('Hard', findRichText: true),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('startup failure shows retry and return-home actions', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..errorToThrow = StateError('boom');
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Return to Home'), findsOneWidget);
    // No raw exception internals leak to the user.
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('retry starts the game again', (tester) async {
    final repo = _FakeWordRepository()..errorToThrow = StateError('boom');
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    repo.errorToThrow = null;
    repo.wordsByLength[4] = 'lace';
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a valid guess is accepted and appears in history', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await enterAndSubmit(tester, 'race');

    expect(find.text('RACE'), findsOneWidget);
    expect(find.textContaining('Bulls:'), findsOneWidget);
    expect(find.textContaining('Cows:'), findsOneWidget);
  });

  testWidgets('accepted guess clears the input field', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await enterAndSubmit(tester, 'race');

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('invalid guess shows a validation message and consumes no '
      'attempt', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    // Shorter than the configured word length; the field's maxLength caps
    // the upper bound only, so this still reaches the validator untouched.
    await enterAndSubmit(tester, 'to');

    expect(find.text('Your guess must be exactly 4 letters.'), findsOneWidget);
    expect(find.textContaining('0 of 10 attempts used'), findsOneWidget);
  });

  testWidgets(
    'a guess absent from the allowed-guess dictionary is rejected with a '
    'visible, accessible message and consumes no attempt or history row',
    (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      // 'qzxj' is alphabetic and exactly 4 letters — it clears every format
      // check — but is deliberately absent from the fake repository's
      // allowed words, so it must be rejected for dictionary absence, not
      // hard-coded as a special case anywhere in the app.
      await enterAndSubmit(tester, 'qzxj');

      expect(
        find.text("That's not a word we recognize. Try another guess."),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          "That's not a word we recognize. Try another guess.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('0 of 10 attempts used'), findsOneWidget);
      // No history row was added: the only guess-history related text on
      // screen is the empty-state, never a scored 'Bulls:'/'Cows:' row.
      expect(find.textContaining('Bulls:'), findsNothing);
    },
  );

  testWidgets('keyboard submit action works', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'race');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('RACE'), findsOneWidget);
  });

  testWidgets('input cannot exceed the configured word length', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'toolongword');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, lessThanOrEqualTo(4));
  });

  testWidgets('active UI does not show the secret word', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    expect(find.text('LACE'), findsNothing);
    expect(find.textContaining('lace'), findsNothing);
  });

  testWidgets('a winning guess shows the win state and secret word', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await enterAndSubmit(tester, 'lace');

    expect(find.text('You won!'), findsOneWidget);
    expect(find.textContaining('LACE'), findsWidgets);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Return to Home'), findsOneWidget);
  });

  testWidgets('a losing final guess shows the loss state and secret word', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    for (var i = 0; i < 9; i++) {
      await enterAndSubmit(tester, 'mock');
    }
    await enterAndSubmit(tester, 'mock');

    expect(find.text('You lost'), findsOneWidget);
    expect(find.textContaining('LACE'), findsWidgets);
  });

  testWidgets('history remains visible after completion', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await enterAndSubmit(tester, 'race');
    await enterAndSubmit(tester, 'lace');

    expect(find.text('RACE'), findsOneWidget);
    expect(find.text('LACE'), findsOneWidget);
  });

  testWidgets('restart starts a new game via GameController.restart', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await enterAndSubmit(tester, 'lace');
    expect(find.text('You won!'), findsOneWidget);

    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('0 of 10 attempts used'), findsOneWidget);
  });

  testWidgets('return home pops the gameplay route', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        GameScreen(controller: controller, config: config4),
                  ),
                ),
                child: const Text('Go to game'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go to game'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await enterAndSubmit(tester, 'lace');
    await tester.tap(find.text('Return to Home'));
    await tester.pumpAndSettle();

    expect(find.text('Go to game'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('major controls have semantic labels', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Submit guess'), findsOneWidget);
    expect(find.bySemanticsLabel('Guess input, 4 letters'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not throw under large text scaling', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: buildSubject(controller, config4),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('builds without exceptions in dark mode', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: GameScreen(controller: controller, config: config4),
      ),
    );
    await tester.pumpAndSettle();
    await enterAndSubmit(tester, 'lace');

    expect(tester.takeException(), isNull);
  });

  testWidgets('the guess field is focused once the game becomes active', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('a rejected guess selects the existing text', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await enterAndSubmit(tester, 'to');

    final field = tester.widget<TextField>(find.byType(TextField));
    final controllerText = field.controller!;
    expect(
      controllerText.selection,
      TextSelection(baseOffset: 0, extentOffset: controllerText.text.length),
    );
  });

  testWidgets('the submit button is enabled during active play', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    'rapid repeated interaction does not duplicate an accepted guess',
    (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'race');
      await tester.tap(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('RACE'), findsOneWidget);
      expect(find.textContaining('1 of 10 attempts used'), findsOneWidget);
    },
  );

  testWidgets('the validation banner is exposed through semantics', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await enterAndSubmit(tester, 'to');

    expect(
      find.bySemanticsLabel('Your guess must be exactly 4 letters.'),
      findsOneWidget,
    );
  });

  testWidgets('a history row exposes turn, guess, and score as text', (
    tester,
  ) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await enterAndSubmit(tester, 'race');

    expect(find.text('1'), findsOneWidget);
    expect(find.text('RACE'), findsOneWidget);
    expect(find.textContaining('Bulls:'), findsOneWidget);
    expect(find.textContaining('Cows:'), findsOneWidget);
  });

  testWidgets('completion exposes the outcome and secret word through '
      'semantics', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await enterAndSubmit(tester, 'lace');

    expect(
      find.bySemanticsLabel(RegExp('You won!.*secret word was lace')),
      findsOneWidget,
    );
  });

  testWidgets('restart restores focus to the guess field', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();

    await enterAndSubmit(tester, 'lace');
    expect(find.text('You won!'), findsOneWidget);

    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
  });

  group('empty guess history guidance', () {
    testWidgets('is shown when a new game begins', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter any 4-letter word to start the game.'),
        findsOneWidget,
      );
    });

    testWidgets('remains visible after an invalid guess, since the game '
        'has not started yet', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      await enterAndSubmit(tester, 'to');

      expect(
        find.text('Your guess must be exactly 4 letters.'),
        findsOneWidget,
      );
      expect(
        find.text('Enter any 4-letter word to start the game.'),
        findsOneWidget,
      );
    });

    testWidgets('disappears immediately after the first valid guess is '
        'accepted', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      await enterAndSubmit(tester, 'race');

      expect(find.text('RACE'), findsOneWidget);
      expect(
        find.text('Enter any 4-letter word to start the game.'),
        findsNothing,
      );
    });

    testWidgets('the old "Start guessing" phrase is never shown', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      expect(find.textContaining('Start guessing'), findsNothing);

      await enterAndSubmit(tester, 'to');
      expect(find.textContaining('Start guessing'), findsNothing);

      await enterAndSubmit(tester, 'race');
      expect(find.textContaining('Start guessing'), findsNothing);
    });
  });

  group('reduced motion', () {
    testWidgets('renders without exceptions when animations are disabled', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: buildSubject(controller, config4),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the validation banner is visible after a single frame (no settling '
      'needed)',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: buildSubject(controller, config4),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'to');
        await tester.tap(find.text('Submit'));
        await tester.pump(); // exactly one frame, no pumpAndSettle

        expect(
          find.text('Your guess must be exactly 4 letters.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'completion content is visible after a single frame (no settling '
      'needed)',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: buildSubject(controller, config4),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'lace');
        await tester.tap(find.text('Submit'));
        await tester.pump(); // exactly one frame, no pumpAndSettle

        expect(find.text('You won!'), findsOneWidget);
        expect(find.textContaining('LACE'), findsWidgets);
      },
    );
  });
}
