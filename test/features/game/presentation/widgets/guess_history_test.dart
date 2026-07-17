import 'package:cowbullgame/features/game/models/guess.dart';
import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:cowbullgame/features/game/presentation/widgets/guess_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(List<Guess> guesses) {
    return MaterialApp(
      home: Scaffold(body: GuessHistory(guesses: guesses)),
    );
  }

  group('empty guess history guidance', () {
    testWidgets('shows "Enter any 4-letter word to start the game." when '
        'there are no guesses yet', (tester) async {
      await tester.pumpWidget(buildSubject(const []));

      expect(
        find.text('Enter any 4-letter word to start the game.'),
        findsOneWidget,
      );
    });

    testWidgets('exposes the guidance through semantics', (tester) async {
      await tester.pumpWidget(buildSubject(const []));

      expect(
        find.bySemanticsLabel('Enter any 4-letter word to start the game.'),
        findsOneWidget,
      );
    });

    testWidgets('never shows the old "Start guessing" phrase', (tester) async {
      await tester.pumpWidget(buildSubject(const []));

      expect(find.textContaining('Start guessing'), findsNothing);
    });

    testWidgets('is hidden once at least one guess has been accepted', (
      tester,
    ) async {
      final guess = Guess(
        word: 'race',
        result: GuessResult(bulls: 1, cows: 2),
        turnNumber: 1,
      );

      await tester.pumpWidget(buildSubject([guess]));

      expect(
        find.text('Enter any 4-letter word to start the game.'),
        findsNothing,
      );
    });
  });
}
