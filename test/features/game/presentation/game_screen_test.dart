import 'dart:async';

import 'package:cowbullgame/coin_wallet.dart';
import 'package:cowbullgame/core/sharing/result_share_service.dart';
import 'package:cowbullgame/features/game/controllers/game_controller.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:cowbullgame/features/game/models/game_config.dart';
import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:cowbullgame/features/game/presentation/game_screen.dart';
import 'package:cowbullgame/features/game/services/game_engine.dart';
import 'package:cowbullgame/models/streak_feedback.dart';
import 'package:cowbullgame/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_game_feedback.dart';
import '../../../support/fake_result_share_service.dart';

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

  Widget buildSubject(
    GameController controller,
    GameConfig config, {
    VoidCallback? onButtonTap,
    ResultShareService? shareService,
    ValueNotifier<StreakFeedback?>? streakFeedback,
    int? currentStreak,
    ResultTextBuilder? resultTextBuilder,
  }) {
    return MaterialApp(
      home: GameScreen(
        controller: controller,
        config: config,
        onButtonTap: onButtonTap,
        shareService: shareService ?? FakeResultShareService(),
        streakFeedback: streakFeedback,
        currentStreak: currentStreak,
        resultTextBuilder: resultTextBuilder,
      ),
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

  testWidgets('restart invokes onButtonTap', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);
    var callCount = 0;

    await tester.pumpWidget(
      buildSubject(controller, config4, onButtonTap: () => callCount++),
    );
    await tester.pumpAndSettle();
    await enterAndSubmit(tester, 'lace');

    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('return home invokes onButtonTap', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);
    var callCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameScreen(
                      controller: controller,
                      config: config4,
                      onButtonTap: () => callCount++,
                    ),
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
    await enterAndSubmit(tester, 'lace');
    await tester.tap(find.text('Return to Home'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('works normally when onButtonTap is left unset', (tester) async {
    final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
    final controller = GameController(wordRepository: repo, gameEngine: engine);

    await tester.pumpWidget(buildSubject(controller, config4));
    await tester.pumpAndSettle();
    await enterAndSubmit(tester, 'lace');

    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
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

  group('Milestone 14: coins and hints', () {
    final hardConfig4 = GameConfig.forSelection(
      wordLength: 4,
      difficulty: GameDifficulty.hard,
    );
    final hintIcon = find.byIcon(Icons.lightbulb_outline);

    testWidgets('shows the coin balance in the app bar', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('Easy shows the "Hint · 20 coins" label', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      expect(find.text('Hint · 20 coins'), findsOneWidget);
    });

    testWidgets('Hard shows the "Free Hint" label before the first use', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, hardConfig4));
      await tester.pumpAndSettle();

      expect(find.text('Free Hint'), findsOneWidget);
    });

    testWidgets('Hard shows "Hint · 20 coins" after the free hint is used', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, hardConfig4));
      await tester.pumpAndSettle();

      await tester.tap(hintIcon);
      await tester.pumpAndSettle();

      expect(find.text('Free Hint'), findsNothing);
      expect(find.text('Hint · 20 coins'), findsOneWidget);
    });

    testWidgets('a free hint requires no confirmation dialog', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, hardConfig4));
      await tester.pumpAndSettle();

      await tester.tap(hintIcon);
      await tester.pumpAndSettle();

      expect(find.text('Use a hint?'), findsNothing);
      expect(find.text('The first letter is L.'), findsOneWidget);
      expect(wallet.balance, 100);
    });

    testWidgets('a paid-hint confirmation shows the cost and current '
        'balance', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      await tester.tap(hintIcon);
      await tester.pumpAndSettle();

      expect(find.text('Use a hint?'), findsOneWidget);
      expect(find.textContaining('Cost: 20 coins'), findsOneWidget);
      expect(find.textContaining('Your balance: 100 coins'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Use 20 Coins'), findsOneWidget);
    });

    testWidgets('confirming a paid hint deducts coins and reveals the '
        'hint', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      await tester.tap(hintIcon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use 20 Coins'));
      await tester.pumpAndSettle();

      expect(wallet.balance, 80);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('The first letter is L.'), findsOneWidget);
    });

    testWidgets('cancelling a paid-hint confirmation leaves the balance '
        'and hint count unchanged', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      await tester.tap(hintIcon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(wallet.balance, 100);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Hint · 20 coins'), findsOneWidget);
      expect(find.textContaining('letter is'), findsNothing);
    });

    testWidgets('a second hint on Easy is unavailable after the first is '
        'used', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();
      await tester.tap(hintIcon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use 20 Coins'));
      await tester.pumpAndSettle();

      expect(find.text('No hints remaining'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'No hints remaining'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an insufficient balance shows clear guidance and disables the '
        'button', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 5);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      expect(find.text('Not enough coins for a hint.'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Hint · 20 coins'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('hints are hidden once the game is won', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.text('You won!'), findsOneWidget);
      expect(hintIcon, findsNothing);
    });

    testWidgets('hints are unavailable before the game has finished '
        'loading', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      // No pumpAndSettle: the game is still loading its secret word.
      expect(hintIcon, findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('a rapid double-tap on the Hint button opens at most one '
        'confirmation dialog and deducts coins at most once', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      await tester.tap(hintIcon);
      await tester.tap(hintIcon, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Use a hint?'), findsOneWidget);

      await tester.tap(find.text('Use 20 Coins'));
      await tester.pumpAndSettle();

      expect(wallet.balance, 80);
    });

    testWidgets('hint information remains readable in dark mode', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: GameScreen(controller: controller, config: hardConfig4),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(hintIcon);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('The first letter is L.'), findsOneWidget);
    });

    testWidgets('hint information remains readable in light mode', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.light,
          themeMode: ThemeMode.light,
          home: GameScreen(controller: controller, config: hardConfig4),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(hintIcon);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('The first letter is L.'), findsOneWidget);
    });

    testWidgets('Milestone 15: the win screen shows how many hints were '
        'used', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      await tester.tap(hintIcon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use 20 Coins'));
      await tester.pumpAndSettle();

      await enterAndSubmit(tester, 'lace');

      expect(find.text('You won!'), findsOneWidget);
      expect(find.text('Hints used: 1'), findsOneWidget);
    });

    testWidgets('Milestone 15: the loss screen shows how many hints were '
        'used', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      for (var i = 0; i < 10; i++) {
        await enterAndSubmit(tester, 'mock');
      }

      expect(find.text('You lost'), findsOneWidget);
      expect(find.text('Hints used: 0'), findsOneWidget);
    });

    testWidgets('Milestone 15: hints used resets to 0 after a restart', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      await tester.tap(hintIcon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use 20 Coins'));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');
      expect(find.text('Hints used: 1'), findsOneWidget);

      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.text('Hints used: 0'), findsOneWidget);
    });

    testWidgets('Milestone 15: a cancelled paid-hint confirmation triggers '
        'no coin-balance animation label', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      await tester.tap(hintIcon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('-20'), findsNothing);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('the hint button has an accessible label', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Use hint for 20 coins'), findsOneWidget);
    });
  });

  group('Milestone 17: sharing', () {
    testWidgets('the Share Result button is absent during an active game', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();

      expect(find.text('Share Result'), findsNothing);
    });

    testWidgets('the Share Result button appears after a win', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.text('You won!'), findsOneWidget);
      expect(find.text('Share Result'), findsOneWidget);
      // Restart/Return Home remain alongside the new Share Result action.
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Return to Home'), findsOneWidget);
    });

    testWidgets('the Share Result button appears after a loss', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        await enterAndSubmit(tester, 'mock');
      }

      expect(find.text('You lost'), findsOneWidget);
      expect(find.text('Share Result'), findsOneWidget);
    });

    testWidgets(
      'tapping Share Result calls the share service exactly once with the '
      'expected text and subject',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        final shareService = FakeResultShareService();

        await tester.pumpWidget(
          buildSubject(controller, config4, shareService: shareService),
        );
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        await tester.tap(find.text('Share Result'));
        await tester.pumpAndSettle();

        expect(shareService.calls, hasLength(1));
        final call = shareService.calls.single;
        expect(call.text, contains('Cow Bull Quest — Easy'));
        expect(call.text, contains('Solved in 1/10 attempts'));
        expect(call.text.toLowerCase(), isNot(contains('lace')));
        expect(call.subject, 'My Cow Bull Quest result');
      },
    );

    testWidgets(
      'rapid repeated taps on Share Result cannot open multiple share '
      'sheets',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        final shareService = FakeResultShareService();
        // A real platform share call always takes some real time; holding
        // this one open on a gate (rather than letting the fake resolve
        // immediately) keeps the share deterministically "in flight" across
        // both taps below, so the second tap genuinely exercises the
        // in-flight guard instead of racing Dart's microtask queue against
        // an instantly-resolving fake.
        final gate = Completer<void>();
        shareService.delay = gate.future;

        await tester.pumpWidget(
          buildSubject(controller, config4, shareService: shareService),
        );
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        await tester.tap(find.text('Share Result'));
        await tester.tap(find.text('Share Result'), warnIfMissed: false);
        gate.complete();
        await tester.pumpAndSettle();

        expect(shareService.calls, hasLength(1));
      },
    );

    testWidgets('a share failure shows readable feedback and does not '
        'crash', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      final shareService = FakeResultShareService()
        ..failWith = Exception('boom');

      await tester.pumpWidget(
        buildSubject(controller, config4, shareService: shareService),
      );
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      await tester.tap(find.text('Share Result'));
      // Deliberately not pumpAndSettle: the shown SnackBar auto-dismisses on
      // its own timer, and pumpAndSettle would pump straight through that
      // entire lifecycle. A couple of bounded pumps is enough to let the
      // async share attempt fail and the SnackBar's entrance animation
      // complete, while it's still on screen to assert against.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(tester.takeException(), isNull);
      expect(
        find.text("Couldn't share your result. Please try again."),
        findsOneWidget,
      );
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('share completion does not alter the completed game, coins, or '
        'navigation', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final wallet = CoinWallet(initialBalance: 100);
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
        coinWallet: wallet,
      );
      final shareService = FakeResultShareService();

      await tester.pumpWidget(
        buildSubject(controller, config4, shareService: shareService),
      );
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      await tester.tap(find.text('Share Result'));
      await tester.pumpAndSettle();

      expect(find.text('You won!'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Return to Home'), findsOneWidget);
      expect(wallet.balance, 100);
    });

    testWidgets('no success message is shown merely because the share '
        'sheet opened', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      final shareService = FakeResultShareService();

      await tester.pumpWidget(
        buildSubject(controller, config4, shareService: shareService),
      );
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      await tester.tap(find.text('Share Result'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('rebuilding the completed screen does not invoke sharing', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      final shareService = FakeResultShareService();

      await tester.pumpWidget(
        buildSubject(controller, config4, shareService: shareService),
      );
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(shareService.calls, isEmpty);
    });

    testWidgets(
      'win sound/haptics are not replayed when Share Result is tapped',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final feedback = FakeGameFeedback();
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
          feedback: feedback,
        );
        final shareService = FakeResultShareService();

        await tester.pumpWidget(
          buildSubject(controller, config4, shareService: shareService),
        );
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(feedback.calls.where((c) => c == 'onGameWon'), hasLength(1));

        await tester.tap(find.text('Share Result'));
        await tester.pumpAndSettle();

        expect(feedback.calls.where((c) => c == 'onGameWon'), hasLength(1));
        expect(feedback.calls.where((c) => c == 'onGameLost'), isEmpty);
      },
    );

    testWidgets('Share Result reuses the button-tap sound via onButtonTap', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      final shareService = FakeResultShareService();
      var tapCount = 0;

      await tester.pumpWidget(
        buildSubject(
          controller,
          config4,
          shareService: shareService,
          onButtonTap: () => tapCount++,
        ),
      );
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');
      tapCount = 0; // a valid guess/win never itself calls onButtonTap

      await tester.tap(find.text('Share Result'));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
      expect(shareService.calls, hasLength(1));
    });

    testWidgets('Restart still works from the completed screen with '
        'sharing controls present', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Share Result'), findsNothing);
      expect(find.textContaining('0 of 10 attempts used'), findsOneWidget);
    });

    testWidgets('Return Home still works from the completed screen with '
        'sharing controls present', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        controller: controller,
                        config: config4,
                        shareService: FakeResultShareService(),
                      ),
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
      await enterAndSubmit(tester, 'lace');

      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();

      expect(find.text('Go to game'), findsOneWidget);
    });

    testWidgets('does not overflow on a narrow screen with sharing controls '
        'visible', (tester) async {
      // The physical size is reset explicitly at the end of this test body,
      // not via addTearDown: resetting during Flutter's own teardown phase
      // — after a guess has just transitioned this screen from the active
      // to the completed view, tearing down GuessInput's TextField — has
      // been observed to hit an unrelated Flutter test-framework timing
      // issue (a stray didChangeMetrics callback reaching an
      // already-deactivated EditableText). Resetting while the test's own
      // widget tree is still fully live and settled avoids that.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(tester.takeException(), isNull);
      expect(find.text('Share Result'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.pump();
    });

    testWidgets('does not overflow under large text scaling with sharing '
        'controls visible', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
          child: buildSubject(controller, config4),
        ),
      );
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(tester.takeException(), isNull);
      expect(find.text('Share Result'), findsOneWidget);
    });

    testWidgets('the Share Result button has a clear semantics label', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.bySemanticsLabel('Share Result'), findsOneWidget);
    });

    testWidgets('Copy Result copies the same privacy-safe text and shows a '
        'confirmation', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      final clipboardCalls = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardCalls.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      await tester.tap(find.byIcon(Icons.copy));
      // Deliberately not pumpAndSettle: the shown SnackBar auto-dismisses
      // on its own timer, and pumpAndSettle would pump straight through
      // that entire lifecycle. A couple of bounded pumps is enough for the
      // confirmation to appear while it's still on screen to assert
      // against.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(clipboardCalls, hasLength(1));
      final copiedText = clipboardCalls.single['text'] as String;
      expect(copiedText, contains('Cow Bull Quest — Easy'));
      expect(copiedText.toLowerCase(), isNot(contains('lace')));
      expect(find.text('Result copied.'), findsOneWidget);
    });

    testWidgets('the Copy Result button has a clear semantics label', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.bySemanticsLabel('Copy Result'), findsOneWidget);
    });

    group('resilience', () {
      testWidgets('sharing still works when onButtonTap is left unset, '
          'simulating sound effects disabled', (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        final shareService = FakeResultShareService();

        await tester.pumpWidget(
          buildSubject(controller, config4, shareService: shareService),
        );
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        await tester.tap(find.text('Share Result'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(shareService.calls, hasLength(1));
      });

      testWidgets('sharing works with animations disabled', (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        final shareService = FakeResultShareService();

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: buildSubject(
              controller,
              config4,
              shareService: shareService,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        await tester.tap(find.text('Share Result'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(shareService.calls, hasLength(1));
      });

      testWidgets(
        'a fake share service throwing an exception does not break the '
        'completed screen',
        (tester) async {
          final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
          final controller = GameController(
            wordRepository: repo,
            gameEngine: engine,
          );
          final shareService = FakeResultShareService()
            ..failWith = StateError('platform channel unavailable');

          await tester.pumpWidget(
            buildSubject(controller, config4, shareService: shareService),
          );
          await tester.pumpAndSettle();
          await enterAndSubmit(tester, 'lace');

          await tester.tap(find.text('Share Result'));
          // Deliberately not pumpAndSettle: the failure SnackBar
          // auto-dismisses on its own timer (see the identical note on the
          // "share failure" test above).
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 750));

          expect(tester.takeException(), isNull);
          expect(find.text('You won!'), findsOneWidget);
          expect(find.text('Restart'), findsOneWidget);
          expect(find.text('Return to Home'), findsOneWidget);
        },
      );
    });
  });

  group('Milestone 18: streak feedback', () {
    testWidgets('shows "Streak started" text for a started streak', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      final streakFeedback = ValueNotifier<StreakFeedback?>(
        const StreakFeedback(
          kind: StreakFeedbackKind.started,
          currentStreak: 1,
        ),
      );

      await tester.pumpWidget(
        buildSubject(controller, config4, streakFeedback: streakFeedback),
      );
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.textContaining('Streak started: 1 day'), findsOneWidget);
    });

    testWidgets('shows "Streak extended" text for an extended streak', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      final streakFeedback = ValueNotifier<StreakFeedback?>(
        const StreakFeedback(
          kind: StreakFeedbackKind.extended,
          currentStreak: 4,
        ),
      );

      await tester.pumpWidget(
        buildSubject(controller, config4, streakFeedback: streakFeedback),
      );
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.textContaining('Streak extended: 4 days'), findsOneWidget);
    });

    testWidgets(
      'shows "Today already counted" text without misleadingly implying a '
      'new extension',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        final streakFeedback = ValueNotifier<StreakFeedback?>(
          const StreakFeedback(
            kind: StreakFeedbackKind.alreadyCounted,
            currentStreak: 4,
          ),
        );

        await tester.pumpWidget(
          buildSubject(controller, config4, streakFeedback: streakFeedback),
        );
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        expect(
          find.textContaining('Today already counted · 4-day streak'),
          findsOneWidget,
        );
        expect(find.textContaining('Streak extended'), findsNothing);
        expect(find.textContaining('Streak started'), findsNothing);
      },
    );

    testWidgets('shows no streak feedback at all when null', (tester) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );

      await tester.pumpWidget(buildSubject(controller, config4));
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      expect(find.textContaining('streak'), findsNothing);
    });

    testWidgets(
      'rebuilding the completed screen with the same streak feedback does '
      'not duplicate the entrance animation (no exception, single banner)',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        final streakFeedback = ValueNotifier<StreakFeedback?>(
          const StreakFeedback(
            kind: StreakFeedbackKind.started,
            currentStreak: 1,
          ),
        );

        await tester.pumpWidget(
          buildSubject(controller, config4, streakFeedback: streakFeedback),
        );
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');
        expect(find.textContaining('Streak started: 1 day'), findsOneWidget);

        // Rebuild for an unrelated reason (a fresh, config-identical
        // widget), without any new completion occurring.
        await tester.pumpWidget(
          buildSubject(controller, config4, streakFeedback: streakFeedback),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Streak started: 1 day'), findsOneWidget);
      },
    );

    testWidgets(
      'resultTextBuilder overrides Share/Copy text instead of the default '
      'formatter',
      (tester) async {
        final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
        final controller = GameController(
          wordRepository: repo,
          gameEngine: engine,
        );
        final clipboardCalls = <Map<Object?, Object?>>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardCalls.add(call.arguments as Map<Object?, Object?>);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        await tester.pumpWidget(
          buildSubject(
            controller,
            config4,
            resultTextBuilder: (state, hintsUsed) => 'custom override text',
          ),
        );
        await tester.pumpAndSettle();
        await enterAndSubmit(tester, 'lace');

        await tester.ensureVisible(find.byIcon(Icons.copy));
        await tester.tap(find.byIcon(Icons.copy));
        await tester.pump();

        expect(clipboardCalls, hasLength(1));
        expect(clipboardCalls.single['text'], 'custom override text');
      },
    );

    testWidgets('currentStreak adds a streak line to the default share text', (
      tester,
    ) async {
      final repo = _FakeWordRepository()..wordsByLength[4] = 'lace';
      final controller = GameController(
        wordRepository: repo,
        gameEngine: engine,
      );
      final clipboardCalls = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardCalls.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        buildSubject(controller, config4, currentStreak: 5),
      );
      await tester.pumpAndSettle();
      await enterAndSubmit(tester, 'lace');

      await tester.ensureVisible(find.byIcon(Icons.copy));
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      expect(clipboardCalls.single['text'], contains('🔥 5-day streak'));
    });
  });
}
