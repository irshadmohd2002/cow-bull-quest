import 'package:cowbullgame/features/rules/presentation/rules_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject() {
    return const MaterialApp(home: RulesScreen());
  }

  testWidgets('shows the title', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.text('How to Play'), findsWidgets);
  });

  testWidgets('explains that the player guesses a secret word', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.textContaining('secret'), findsWidgets);
  });

  testWidgets('explains the bull definition', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.text('Bulls'), findsWidgets);
    expect(
      find.textContaining('correct and in the right position'),
      findsOneWidget,
    );
  });

  testWidgets('explains the cow definition', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.text('Cows'), findsWidgets);
    expect(
      find.textContaining('correct but in the wrong position'),
      findsOneWidget,
    );
  });

  testWidgets('explains the duplicate-letter rule', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(
      find.textContaining('never be counted more times than it'),
      findsOneWidget,
    );
  });

  testWidgets('explains invalid guesses do not consume attempts', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    expect(find.textContaining('does not use up an attempt'), findsOneWidget);
  });

  testWidgets('states every game uses a 4-letter secret word and 10 '
      'attempts', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.textContaining('4-letter secret word'), findsOneWidget);
    expect(find.textContaining('10 attempts'), findsOneWidget);
  });

  group('difficulty explanations', () {
    testWidgets('shows all three difficulty headings', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('never shows "Common" as a difficulty label', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Common'), findsNothing);
    });

    testWidgets('explains each difficulty tier', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.textContaining('high-frequency words'), findsOneWidget);
      expect(find.textContaining('everyday vocabulary'), findsOneWidget);
      expect(find.textContaining('Less frequent words'), findsOneWidget);
    });

    testWidgets('clarifies difficulty only changes vocabulary, not word '
        'length or attempts', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(
        find.textContaining('Difficulty only changes which vocabulary'),
        findsOneWidget,
      );
    });
  });

  testWidgets('renders both worked examples', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.text('Secret: APPLE'), findsOneWidget);
    expect(find.text('Guess: AMPLE'), findsOneWidget);
    expect(find.text('Secret: SPEED'), findsOneWidget);
    expect(find.text('Guess: EERIE'), findsOneWidget);
  });

  testWidgets('exposes example results as text', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.textContaining('Bulls: 4   Cows: 0'), findsOneWidget);
    expect(find.textContaining('Bulls: 0   Cows: 2'), findsOneWidget);
  });

  testWidgets('exposes example results through semantics', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.bySemanticsLabel(RegExp('4 bulls, 0 cows')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('0 bulls, 2 cows')), findsOneWidget);
  });

  testWidgets('scrolls on a narrow display without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('does not throw under large text scaling', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: buildSubject(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the three section headings', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.text('Scoring'), findsOneWidget);
    expect(find.text('Difficulty'), findsOneWidget);
    expect(find.text('Examples'), findsOneWidget);
  });

  testWidgets('each rule item exposes exactly one semantic label, not one '
      'per line of text', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(
      find.bySemanticsLabel(
        'Bulls: A bull is a letter that is correct and in the right '
        'position.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders without exceptions when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: buildSubject(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('How to Play'), findsWidgets);
  });

  group('Milestone 14: coins and hints explanation', () {
    testWidgets('shows the Coins & Hints section heading', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Coins & Hints'), findsOneWidget);
    });

    testWidgets('states new players begin with 100 coins', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.textContaining('begin with 100 coins'), findsOneWidget);
    });

    testWidgets('explains a hint reveals one letter and its position', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      expect(
        find.textContaining(
          'reveals one correct letter and its exact '
          'position',
        ),
        findsOneWidget,
      );
    });

    testWidgets('explains Easy and Medium allow one paid hint costing 20 '
        'coins', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Easy and Medium hints'), findsOneWidget);
      expect(
        find.textContaining('One hint per game, costing 20 coins'),
        findsOneWidget,
      );
    });

    testWidgets('explains Hard allows one free hint and one paid hint', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Hard hints'), findsOneWidget);
      expect(
        find.textContaining('the first is free, the second costs 20 coins'),
        findsOneWidget,
      );
    });

    testWidgets('states hints do not use up an attempt', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.textContaining('never uses up an attempt'), findsOneWidget);
    });

    testWidgets('states coins are stored only on this device', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.textContaining('stored only on this device'), findsOneWidget);
    });

    testWidgets('never mentions cash, money, or real-world redemption', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      expect(find.textContaining('cash'), findsNothing);
      expect(find.textContaining('real money'), findsNothing);
    });
  });

  group('Milestone 19: coin rewards explanation', () {
    testWidgets('shows the Coin Rewards section heading', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Coin Rewards'), findsOneWidget);
    });

    testWidgets('states the Easy win reward', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Easy win'), findsOneWidget);
      expect(find.text('10 coins.'), findsOneWidget);
    });

    testWidgets('states the Medium win reward', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Medium win'), findsOneWidget);
      expect(find.text('15 coins.'), findsOneWidget);
    });

    testWidgets('states the Hard win reward', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Hard win'), findsOneWidget);
      expect(find.text('20 coins.'), findsOneWidget);
    });

    testWidgets('states the no-hint win bonus', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('No-hint win bonus'), findsOneWidget);
      expect(
        find.textContaining('+5 coins for winning without a hint'),
        findsOneWidget,
      );
    });

    testWidgets('states the first official Daily Challenge win bonus', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('First official Daily Challenge win'), findsOneWidget);
      expect(find.textContaining('+10 coins'), findsOneWidget);
    });

    testWidgets('states paid hints cost 20 coins', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Paid hints cost 20 coins'), findsOneWidget);
    });

    testWidgets(
      'explains a Daily Challenge replay earns no coins, since the word '
      'is already known',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.text('Replays earn no coins'), findsOneWidget);
        expect(
          find.textContaining('never earns any coins at all'),
          findsOneWidget,
        );
      },
    );

    testWidgets('never mentions cash, money, or real-world redemption', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      expect(find.textContaining('cash'), findsNothing);
      expect(find.textContaining('real money'), findsNothing);
    });
  });
}
