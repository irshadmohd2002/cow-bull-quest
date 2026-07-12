import 'package:cowbullgame/features/game/controllers/game_controller.dart';
import 'package:cowbullgame/features/game/data/word_repository.dart';
import 'package:cowbullgame/features/game/models/game_config.dart';
import 'package:cowbullgame/features/game/presentation/game_screen.dart';
import 'package:cowbullgame/features/game/services/game_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [WordRepository] fake: resolves [selectSecretWord] from
/// [wordsByLength], or throws [errorToThrow] if set. Mirrors the fake used
/// in `game_controller_test.dart` so widget tests never need real Flutter
/// assets.
class _FakeWordRepository implements WordRepository {
  final Map<int, String> wordsByLength = {};
  Object? errorToThrow;

  @override
  Future<String> selectSecretWord(int wordLength) async {
    final error = errorToThrow;
    if (error != null) throw error;
    final word = wordsByLength[wordLength];
    if (word == null) {
      throw StateError('no fake secret word registered for length $wordLength');
    }
    return word;
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

    expect(find.textContaining('4'), findsWidgets);
    expect(find.textContaining('10'), findsWidgets); // max attempts for 4
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
    expect(find.textContaining('Attempts used: 0'), findsOneWidget);
  });

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
    expect(find.textContaining('Attempts used: 0'), findsOneWidget);
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
}
