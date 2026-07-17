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

  group('Milestone 15: new-row entrance animation', () {
    final firstGuess = Guess(
      word: 'race',
      result: GuessResult(bulls: 1, cows: 2),
      turnNumber: 1,
    );
    final secondGuess = Guess(
      word: 'lace',
      result: GuessResult(bulls: 4, cows: 0),
      turnNumber: 2,
    );

    testWidgets('a newly accepted guess fades/slides in rather than '
        'appearing at full opacity on the very first frame', (tester) async {
      await tester.pumpWidget(buildSubject([firstGuess]));
      await tester.pumpAndSettle();

      await tester.pumpWidget(buildSubject([firstGuess, secondGuess]));
      await tester.pump(); // exactly one frame into the entrance animation

      final fadeFinder = find.byKey(const ValueKey('guess-entrance-fade-2'));
      final fade = tester.widget<FadeTransition>(fadeFinder);
      expect(fade.opacity.value, lessThan(1.0));

      await tester.pumpAndSettle();
      final settledFade = tester.widget<FadeTransition>(fadeFinder);
      expect(settledFade.opacity.value, 1.0);
    });

    testWidgets('a previously shown row does not replay its entrance '
        'animation when a new row is added above it', (tester) async {
      await tester.pumpWidget(buildSubject([firstGuess]));
      await tester.pumpAndSettle();

      await tester.pumpWidget(buildSubject([firstGuess, secondGuess]));
      await tester.pump();

      final oldFade = tester.widget<FadeTransition>(
        find.byKey(const ValueKey('guess-entrance-fade-1')),
      );
      expect(oldFade.opacity.value, 1.0);
    });

    testWidgets('a newly appended guess jumps straight to fully visible when '
        'animations are disabled', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: buildSubject([firstGuess]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: buildSubject([firstGuess, secondGuess]),
        ),
      );
      await tester.pump();

      final fade = tester.widget<FadeTransition>(
        find.byKey(const ValueKey('guess-entrance-fade-2')),
      );
      expect(fade.opacity.value, 1.0);
    });

    testWidgets(
      'resets cleanly (no crash, no stale rows) when the guess list shrinks '
      'back to empty, e.g. on restart',
      (tester) async {
        await tester.pumpWidget(buildSubject([firstGuess, secondGuess]));
        await tester.pumpAndSettle();
        expect(find.text('RACE'), findsOneWidget);
        expect(find.text('LACE'), findsOneWidget);

        await tester.pumpWidget(buildSubject(const []));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('RACE'), findsNothing);
        expect(find.text('LACE'), findsNothing);
        expect(
          find.text('Enter any 4-letter word to start the game.'),
          findsOneWidget,
        );

        final thirdGuess = Guess(
          word: 'mock',
          result: GuessResult(bulls: 0, cows: 0),
          turnNumber: 1,
        );
        await tester.pumpWidget(buildSubject([thirdGuess]));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('MOCK'), findsOneWidget);
      },
    );
  });
}
