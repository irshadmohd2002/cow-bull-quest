import 'package:cowbullgame/features/home/presentation/home_screen.dart';
import 'package:cowbullgame/models/difficulty_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(
    void Function(int wordLength, DifficultyOption difficulty) onStartGame, {
    VoidCallback? onOpenRules,
    VoidCallback? onOpenSettings,
  }) {
    return MaterialApp(
      home: HomeScreen(
        onStartGame: onStartGame,
        onOpenRules: onOpenRules ?? () {},
        onOpenSettings: onOpenSettings ?? () {},
      ),
    );
  }

  testWidgets('shows the app title', (tester) async {
    await tester.pumpWidget(buildSubject((_, _) {}));
    expect(find.text('Bulls & Cows'), findsWidgets);
  });

  testWidgets('briefly explains the game', (tester) async {
    await tester.pumpWidget(buildSubject((_, _) {}));
    expect(find.textContaining('bull'), findsWidgets);
    expect(find.textContaining('cow'), findsWidgets);
  });

  testWidgets('shows 4, 5, and 6 letter options', (tester) async {
    await tester.pumpWidget(buildSubject((_, _) {}));
    expect(find.text('4 letters'), findsOneWidget);
    expect(find.text('5 letters'), findsOneWidget);
    expect(find.text('6 letters'), findsOneWidget);
  });

  testWidgets('defaults to the 4-letter option selected', (tester) async {
    await tester.pumpWidget(buildSubject((_, _) {}));
    final segmentedButton = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(segmentedButton.selected, {4});
  });

  testWidgets('selecting an option updates the visible selection', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_, _) {}));

    await tester.tap(find.text('6 letters'));
    await tester.pumpAndSettle();

    final segmentedButton = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(segmentedButton.selected, {6});
  });

  testWidgets('starting the game emits the selected word length', (
    tester,
  ) async {
    int? startedWordLength;
    await tester.pumpWidget(
      buildSubject((wordLength, difficulty) => startedWordLength = wordLength),
    );

    await tester.tap(find.text('5 letters'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(startedWordLength, 5);
  });

  testWidgets('starting without changing the selection uses the default '
      'option', (tester) async {
    int? startedWordLength;
    await tester.pumpWidget(
      buildSubject((wordLength, difficulty) => startedWordLength = wordLength),
    );

    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(startedWordLength, 4);
  });

  testWidgets('has a semantic label for the word length selection', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_, _) {}));
    expect(find.bySemanticsLabel('Word length selection'), findsOneWidget);
  });

  testWidgets('shows the Start Game action', (tester) async {
    await tester.pumpWidget(buildSubject((_, _) {}));
    expect(find.widgetWithText(FilledButton, 'Start Game'), findsOneWidget);
  });

  testWidgets('shows the How to Play action', (tester) async {
    await tester.pumpWidget(buildSubject((_, _) {}));
    expect(find.text('How to Play'), findsOneWidget);
  });

  testWidgets('shows the Settings action', (tester) async {
    await tester.pumpWidget(buildSubject((_, _) {}));
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Start Game is visually distinct from the secondary actions', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_, _) {}));
    expect(find.widgetWithText(FilledButton, 'Start Game'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'How to Play'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Settings'), findsOneWidget);
  });

  testWidgets('tapping How to Play invokes onOpenRules exactly once', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(
      buildSubject((_, _) {}, onOpenRules: () => callCount++),
    );

    await tester.ensureVisible(find.text('How to Play'));
    await tester.tap(find.text('How to Play'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('tapping Settings invokes onOpenSettings exactly once', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(
      buildSubject((_, _) {}, onOpenSettings: () => callCount++),
    );

    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('starting the game invokes onStartGame exactly once', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(buildSubject((_, _) => callCount++));

    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  group('HomeScreen difficulty selection', () {
    testWidgets('shows Easy, Common, and Hard options', (tester) async {
      await tester.pumpWidget(buildSubject((_, _) {}));
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Common'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('shows a concise description for each difficulty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_, _) {}));
      expect(find.textContaining('high-frequency'), findsOneWidget);
      expect(find.textContaining('everyday vocabulary'), findsOneWidget);
      expect(find.textContaining('trickier'), findsOneWidget);
    });

    testWidgets('defaults to Common selected', (tester) async {
      await tester.pumpWidget(buildSubject((_, _) {}));
      final segmentedButton = tester.widget<SegmentedButton<DifficultyOption>>(
        find.byType(SegmentedButton<DifficultyOption>),
      );
      expect(segmentedButton.selected, {DifficultyOption.common});
    });

    testWidgets('selecting a difficulty updates the visible selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_, _) {}));

      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<DifficultyOption>>(
        find.byType(SegmentedButton<DifficultyOption>),
      );
      expect(segmentedButton.selected, {DifficultyOption.hard});
    });

    testWidgets('starting the game emits the selected difficulty', (
      tester,
    ) async {
      DifficultyOption? startedDifficulty;
      await tester.pumpWidget(
        buildSubject(
          (wordLength, difficulty) => startedDifficulty = difficulty,
        ),
      );

      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(startedDifficulty, DifficultyOption.easy);
    });

    testWidgets('starting without changing the selection uses the '
        'documented default (Common)', (tester) async {
      DifficultyOption? startedDifficulty;
      await tester.pumpWidget(
        buildSubject(
          (wordLength, difficulty) => startedDifficulty = difficulty,
        ),
      );

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(startedDifficulty, DifficultyOption.common);
    });

    testWidgets('has a semantic label for the difficulty selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_, _) {}));
      expect(find.bySemanticsLabel('Difficulty selection'), findsOneWidget);
    });

    testWidgets('starting the game emits both word length and difficulty', (
      tester,
    ) async {
      int? startedWordLength;
      DifficultyOption? startedDifficulty;
      await tester.pumpWidget(
        buildSubject((wordLength, difficulty) {
          startedWordLength = wordLength;
          startedDifficulty = difficulty;
        }),
      );

      await tester.tap(find.text('6 letters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(startedWordLength, 6);
      expect(startedDifficulty, DifficultyOption.hard);
    });
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject((_, _) {}));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not throw under large text scaling', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: buildSubject((_, _) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
