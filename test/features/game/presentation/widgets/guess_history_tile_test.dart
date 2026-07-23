import 'package:cowbullgame/features/game/models/guess.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:cowbullgame/features/game/presentation/widgets/guess_history_tile.dart';
import 'package:cowbullgame/widgets/cow_head_icon.dart';
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

  testWidgets('shows the attempt number, guessed word, and its bulls/cows '
      'counts', (tester) async {
    await tester.pumpWidget(buildSubject(guess));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('RACE'), findsOneWidget);
    expect(find.text('Bull 1'), findsOneWidget);
    expect(find.text('Cows 2'), findsOneWidget);
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
    'area previously had no Expanded/Flexible sibling to shrink, and '
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
      'color: a target for Bull, a cow head for Cow', (tester) async {
    await tester.pumpWidget(buildSubject(guess));

    expect(find.byIcon(Icons.gps_fixed_rounded), findsOneWidget);
    expect(find.byType(CowHeadIcon), findsOneWidget);
  });

  testWidgets('both Bull and Cow labels and counts stay on a single line', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(guess));

    final bullText = tester.widget<Text>(find.text('Bull 1'));
    final cowText = tester.widget<Text>(find.text('Cows 2'));
    expect(bullText.maxLines, 1);
    expect(cowText.maxLines, 1);
  });

  testWidgets('uses singular "Bull"/"Cow" at a count of exactly 1', (
    tester,
  ) async {
    final oneEach = Guess(
      word: 'race',
      result: GuessResult(bulls: 1, cows: 1),
      turnNumber: 1,
    );
    await tester.pumpWidget(buildSubject(oneEach));

    expect(find.text('Bull 1'), findsOneWidget);
    expect(find.text('Cow 1'), findsOneWidget);
    expect(find.text('Bulls 1'), findsNothing);
    expect(find.text('Cows 1'), findsNothing);
  });

  testWidgets('uses plural "Bulls"/"Cows" at a count of 0', (tester) async {
    final zeroEach = Guess(
      word: 'race',
      result: GuessResult(bulls: 0, cows: 0),
      turnNumber: 1,
    );
    await tester.pumpWidget(buildSubject(zeroEach));

    expect(find.text('Bulls 0'), findsOneWidget);
    expect(find.text('Cows 0'), findsOneWidget);
  });
}
