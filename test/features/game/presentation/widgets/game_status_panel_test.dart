import 'package:cowbullgame/features/game/controllers/game_controller_state.dart';
import 'package:cowbullgame/features/game/models/game_session.dart';
import 'package:cowbullgame/features/game/models/guess.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:cowbullgame/features/game/presentation/widgets/game_status_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [GameSessionView] for a 4-letter session with [attemptsUsed]
/// (content-agnostic) guesses already made out of [maxAttempts].
GameSessionView _viewWith({
  required int attemptsUsed,
  required int maxAttempts,
}) {
  final session = GameSession.start('lace', maxAttempts: maxAttempts).copyWith(
    guesses: [
      for (var turn = 1; turn <= attemptsUsed; turn++)
        Guess(
          word: 'abcd',
          result: GuessResult(bulls: 0, cows: 0),
          turnNumber: turn,
        ),
    ],
  );
  return GameSessionView.fromSession(session);
}

Widget buildSubject(GameSessionView view, {String difficultyLabel = 'Common'}) {
  return MaterialApp(
    home: Scaffold(
      body: GameStatusPanel(view: view, difficultyLabel: difficultyLabel),
    ),
  );
}

void main() {
  testWidgets(
    'shows attempts used and remaining in the always-visible summary text',
    (tester) async {
      final view = _viewWith(attemptsUsed: 3, maxAttempts: 10);
      await tester.pumpWidget(buildSubject(view));

      expect(find.text('3 of 10 attempts used · 7 remaining'), findsOneWidget);
    },
  );

  testWidgets('the summary is present without any scrolling', (tester) async {
    final view = _viewWith(attemptsUsed: 3, maxAttempts: 10);
    await tester.pumpWidget(buildSubject(view));

    // Found immediately after the initial pump, with no drag/scroll of any
    // kind performed — unlike the stat chips, which live in the one
    // ListView this panel contains.
    expect(find.text('3 of 10 attempts used · 7 remaining'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('the summary updates as attempts change', (tester) async {
    final view = _viewWith(attemptsUsed: 0, maxAttempts: 10);
    await tester.pumpWidget(buildSubject(view));
    expect(find.text('0 of 10 attempts used · 10 remaining'), findsOneWidget);

    await tester.pumpWidget(
      buildSubject(_viewWith(attemptsUsed: 9, maxAttempts: 10)),
    );
    expect(find.text('9 of 10 attempts used · 1 remaining'), findsOneWidget);
  });

  testWidgets('status semantics remain a single concise label', (tester) async {
    final view = _viewWith(attemptsUsed: 3, maxAttempts: 10);
    await tester.pumpWidget(buildSubject(view, difficultyLabel: 'Hard'));

    expect(
      find.bySemanticsLabel(
        'Word length 4. Difficulty Hard. Attempts used 3 of 10. '
        'Attempts remaining 7.',
      ),
      findsOneWidget,
    );
    // The new summary text must not add a second, duplicate announcement.
    expect(
      find.bySemanticsLabel('3 of 10 attempts used · 7 remaining'),
      findsNothing,
    );
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final view = _viewWith(attemptsUsed: 3, maxAttempts: 10);
    await tester.pumpWidget(buildSubject(view));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('3 of 10 attempts used · 7 remaining'), findsOneWidget);
  });

  testWidgets(
    'the chip row shows exactly word length and difficulty - no redundant, '
    'clippable attempts chips',
    (tester) async {
      final view = _viewWith(attemptsUsed: 3, maxAttempts: 10);
      await tester.pumpWidget(buildSubject(view, difficultyLabel: 'Hard'));

      expect(find.byType(Chip), findsNWidgets(2));
      expect(
        find.textContaining('Word length', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Hard', findRichText: true), findsOneWidget);
    },
  );

  testWidgets('does not overflow under large text scaling', (tester) async {
    final view = _viewWith(attemptsUsed: 3, maxAttempts: 10);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: buildSubject(view),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('attempts used'), findsOneWidget);
  });
}
