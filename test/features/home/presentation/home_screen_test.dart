import 'package:cowbullgame/features/home/presentation/home_screen.dart';
import 'package:cowbullgame/models/difficulty_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(
    void Function(DifficultyOption difficulty) onStartGame, {
    VoidCallback? onOpenRules,
    VoidCallback? onOpenSettings,
    VoidCallback? onOpenStatistics,
    int coinBalance = 100,
  }) {
    return MaterialApp(
      home: HomeScreen(
        onStartGame: onStartGame,
        onOpenRules: onOpenRules ?? () {},
        onOpenSettings: onOpenSettings ?? () {},
        onOpenStatistics: onOpenStatistics ?? () {},
        coinBalance: coinBalance,
      ),
    );
  }

  testWidgets('shows the app title', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.text('Cow Bull Quest'), findsWidgets);
  });

  testWidgets('briefly explains the game', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.textContaining('bull'), findsWidgets);
    expect(find.textContaining('cow'), findsWidgets);
  });

  testWidgets('does not show a word-length selector', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.text('Word length'), findsNothing);
    expect(find.text('4 letters'), findsNothing);
    expect(find.text('5 letters'), findsNothing);
    expect(find.text('6 letters'), findsNothing);
    expect(find.bySemanticsLabel('Word length selection'), findsNothing);
  });

  testWidgets('explains every game uses a 4-letter word with 10 attempts', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.textContaining('4-letter'), findsWidgets);
    expect(find.textContaining('10 attempts'), findsWidgets);
  });

  testWidgets('shows the Start Game action', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.widgetWithText(FilledButton, 'Start Game'), findsOneWidget);
  });

  testWidgets('shows the How to Play action', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.text('How to Play'), findsOneWidget);
  });

  testWidgets('shows the Settings action', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('shows the Statistics action', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.text('Statistics'), findsOneWidget);
  });

  testWidgets('Start Game is visually distinct from the secondary actions', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.widgetWithText(FilledButton, 'Start Game'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'How to Play'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Settings'), findsOneWidget);
  });

  testWidgets('tapping How to Play invokes onOpenRules exactly once', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(
      buildSubject((_) {}, onOpenRules: () => callCount++),
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
      buildSubject((_) {}, onOpenSettings: () => callCount++),
    );

    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('tapping Statistics invokes onOpenStatistics exactly once', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(
      buildSubject((_) {}, onOpenStatistics: () => callCount++),
    );

    await tester.ensureVisible(find.text('Statistics'));
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('starting the game invokes onStartGame exactly once', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(buildSubject((_) => callCount++));

    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  group('HomeScreen difficulty selection', () {
    testWidgets('shows Easy, Medium, and Hard options', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('never shows "Common" as a difficulty label', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));
      expect(find.text('Common'), findsNothing);
    });

    testWidgets('shows a concise description for each difficulty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_) {}));
      expect(find.textContaining('high-frequency'), findsOneWidget);
      expect(find.textContaining('everyday vocabulary'), findsOneWidget);
      expect(find.textContaining('trickier'), findsOneWidget);
    });

    testWidgets('defaults to Medium selected', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));
      final segmentedButton = tester.widget<SegmentedButton<DifficultyOption>>(
        find.byType(SegmentedButton<DifficultyOption>),
      );
      expect(segmentedButton.selected, {DifficultyOption.common});
    });

    testWidgets('selecting a difficulty updates the visible selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_) {}));

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
        buildSubject((difficulty) => startedDifficulty = difficulty),
      );

      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(startedDifficulty, DifficultyOption.easy);
    });

    testWidgets('starting without changing the selection uses the '
        'documented default (Medium/common)', (tester) async {
      DifficultyOption? startedDifficulty;
      await tester.pumpWidget(
        buildSubject((difficulty) => startedDifficulty = difficulty),
      );

      await tester.ensureVisible(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(startedDifficulty, DifficultyOption.common);
    });

    testWidgets('has a semantic label for the difficulty selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_) {}));
      expect(find.bySemanticsLabel('Difficulty selection'), findsOneWidget);
    });

    testWidgets('every difficulty is reachable and each starts a game', (
      tester,
    ) async {
      for (final option in DifficultyOption.values) {
        DifficultyOption? startedDifficulty;
        await tester.pumpWidget(
          buildSubject((difficulty) => startedDifficulty = difficulty),
        );

        final label = switch (option) {
          DifficultyOption.easy => 'Easy',
          DifficultyOption.common => 'Medium',
          DifficultyOption.hard => 'Hard',
        };
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Start Game'));
        await tester.tap(find.text('Start Game'));
        await tester.pumpAndSettle();

        expect(startedDifficulty, option);
      }
    });
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject((_) {}));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not throw under large text scaling', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: buildSubject((_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('selector label wrapping fix', () {
    /// Every [Text] rendered inside a [SegmentedButton] of type [T] is
    /// configured to never wrap onto a second line - the structural half of
    /// the "Medium" wrapping fix (the other half, [FittedBox] scale-down, is
    /// what keeps that single line from overflowing/clipping instead).
    void expectSingleLineSegments<T>(WidgetTester tester) {
      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(SegmentedButton<T>),
          matching: find.byType(Text),
        ),
      );
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
      }
    }

    testWidgets(
      'Easy/Medium/Hard segment labels are configured as single-line',
      (tester) async {
        await tester.pumpWidget(buildSubject((_) {}));
        expectSingleLineSegments<DifficultyOption>(tester);
      },
    );

    testWidgets(
      'Easy, Medium, and Hard remain visible without overflow at 320x568',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildSubject((_) {}));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Easy'), findsOneWidget);
        expect(find.text('Medium'), findsOneWidget);
        expect(find.text('Hard'), findsOneWidget);
      },
    );

    testWidgets(
      'Easy, Medium, and Hard remain visible without overflow at 3x text '
      'scale',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
            child: buildSubject((_) {}),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Easy'), findsOneWidget);
        expect(find.text('Medium'), findsOneWidget);
        expect(find.text('Hard'), findsOneWidget);
      },
    );

    testWidgets('the difficulty selector keeps at least a 48 logical-pixel tap '
        'target height', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));
      final size = tester.getSize(
        find.byType(SegmentedButton<DifficultyOption>),
      );
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('selecting Medium still updates the selection (semantic '
        'label is preserved, not just the shrunk visual label)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_) {}));

      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<DifficultyOption>>(
        find.byType(SegmentedButton<DifficultyOption>),
      );
      expect(segmentedButton.selected, {DifficultyOption.common});
    });
  });

  group('Milestone 15: difficulty icons', () {
    testWidgets('shows a distinct icon for each difficulty', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));

      expect(find.byIcon(Icons.track_changes), findsOneWidget); // selected
      expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
    });

    testWidgets('the selected segment shows the filled icon variant, '
        'unselected segments show the outlined variant', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));

      // Medium is selected by default.
      expect(find.byIcon(Icons.track_changes), findsOneWidget);
      expect(find.byIcon(Icons.track_changes_outlined), findsNothing);
      expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
      expect(find.byIcon(Icons.eco), findsNothing);

      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_outlined), findsNothing);
      expect(find.byIcon(Icons.track_changes_outlined), findsOneWidget);
      expect(find.byIcon(Icons.track_changes), findsNothing);
    });
  });

  group('branding', () {
    testWidgets('displays the approved branding icon as a runtime asset', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_) {}));

      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as AssetImage;
      expect(provider.assetName, 'assets/branding/cow_bull_quest_icon.png');
    });

    testWidgets('the branding icon is marked decorative so the adjacent '
        'title is not announced twice', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));

      expect(
        find.ancestor(
          of: find.byType(Image),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('Start Game has a minimum accessible tap target height', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_) {}));

    final size = tester.getSize(
      find.widgetWithText(FilledButton, 'Start Game'),
    );
    expect(size.height, greaterThanOrEqualTo(44));
  });

  group('reduced motion', () {
    testWidgets('renders without exceptions when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: buildSubject((_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Milestone 14: coin balance', () {
    testWidgets('shows the coin balance', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}, coinBalance: 100));
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('reflects an updated balance', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}, coinBalance: 250));
      expect(find.text('250'), findsOneWidget);
      expect(find.text('100'), findsNothing);
    });

    testWidgets('has an accessible label', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}, coinBalance: 100));
      expect(find.bySemanticsLabel('100 coins'), findsOneWidget);
    });
  });
}
