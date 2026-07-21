import 'package:cowbullgame/features/game/models/guess.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:cowbullgame/features/game/presentation/widgets/guess_history_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(Guess guess) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: GuessHistoryTile(guess: guess)),
      ),
    );
  }

  final guess = Guess(
    word: 'race',
    result: GuessResult(bulls: 1, cows: 2),
    turnNumber: 1,
  );

  testWidgets('shows the guessed word and its bulls/cows counts', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(guess));

    expect(find.text('RACE'), findsOneWidget);
    expect(find.text('Bulls: 1'), findsOneWidget);
    expect(find.text('Cows: 2'), findsOneWidget);
  });

  testWidgets('exposes a single semantics label with the turn, word, and '
      'counts', (tester) async {
    await tester.pumpWidget(buildSubject(guess));

    expect(
      find.bySemanticsLabel('Guess 1: race, 1 bull, 2 cows'),
      findsOneWidget,
    );
  });

  testWidgets(
    'does not overflow on a narrow screen at a large text scale, even with '
    'a double-digit turn number (regression: the trailing Bulls/Cows badge '
    'column previously had no Expanded/Flexible sibling to shrink, and '
    'overflowed by 97px under these exact conditions)',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lateGuess = Guess(
        word: 'race',
        result: GuessResult(bulls: 4, cows: 0),
        turnNumber: 10,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
          child: buildSubject(lateGuess),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('does not overflow at a typical phone screenshot size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject(guess));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('conveys bulls and cows through distinct icons, not just '
      'color', (tester) async {
    await tester.pumpWidget(buildSubject(guess));

    expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    expect(find.byIcon(Icons.sync_alt), findsOneWidget);
  });
}
