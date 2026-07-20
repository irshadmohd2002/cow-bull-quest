import 'package:cowbullgame/features/home/models/daily_challenge_card_status.dart';
import 'package:cowbullgame/features/home/presentation/home_screen.dart';
import 'package:cowbullgame/models/difficulty_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_share_card_renderer.dart';
import '../../../support/fake_share_card_service.dart';

void main() {
  Widget buildSubject(
    void Function(DifficultyOption difficulty) onStartGame, {
    VoidCallback? onOpenRules,
    VoidCallback? onOpenSettings,
    VoidCallback? onOpenStatistics,
    int coinBalance = 100,
    int currentStreak = 0,
    int longestStreak = 0,
    DailyChallengeCardStatus dailyChallengeStatus =
        DailyChallengeCardStatus.notPlayed,
    String dailyChallengeDateLabel = '18 July 2026',
    VoidCallback? onOpenDailyChallenge,
    ValueChanged<DifficultyOption>? onDifficultySelected,
    FakeShareCardRenderer? shareCardRenderer,
    FakeShareCardService? shareCardService,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme,
      home: HomeScreen(
        onStartGame: onStartGame,
        onOpenRules: onOpenRules ?? () {},
        onOpenSettings: onOpenSettings ?? () {},
        onOpenStatistics: onOpenStatistics ?? () {},
        coinBalance: coinBalance,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        dailyChallengeStatus: dailyChallengeStatus,
        dailyChallengeDateLabel: dailyChallengeDateLabel,
        onOpenDailyChallenge: onOpenDailyChallenge ?? () {},
        onDifficultySelected: onDifficultySelected,
        shareCardRenderer: shareCardRenderer ?? FakeShareCardRenderer(),
        shareCardService: shareCardService ?? FakeShareCardService(),
      ),
    );
  }

  /// Pumps enough frames for the share-card preview sheet to finish opening
  /// and its (fake, near-instant) render to complete.
  ///
  /// Deliberately not `pumpAndSettle`: `ShareStreakButton` shows an
  /// indeterminate spinner for as long as the preview sheet stays open,
  /// which `pumpAndSettle` can never treat as "settled".
  Future<void> pumpForPreviewToOpen(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
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

  testWidgets('shows a short, concise gameplay explanation', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(
      find.textContaining('Guess the hidden 4-letter word'),
      findsOneWidget,
    );
  });

  testWidgets('no longer shows the old, longer explanatory paragraph', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(
      find.textContaining('Each guess earns a bull for every letter'),
      findsNothing,
    );
  });

  testWidgets('shows the shortened branding subtitle', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.text('A quick game of bulls and cows.'), findsOneWidget);
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

  group('persistent Start Game action', () {
    testWidgets('only one Start Game action exists on the screen', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_) {}));
      expect(find.text('Start Game'), findsOneWidget);
    });

    testWidgets('is placed in the Scaffold bottom action area', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNotNull);
      expect(scaffold.floatingActionButton, isNull);
      expect(
        find.descendant(
          of: find.byWidget(scaffold.bottomNavigationBar!),
          matching: find.widgetWithText(FilledButton, 'Start Game'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is visible without scrolling at a typical phone size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject((_) {}));
      await tester.pumpAndSettle();

      final rect = tester.getRect(
        find.widgetWithText(FilledButton, 'Start Game'),
      );
      expect(rect.bottom, lessThanOrEqualTo(740));
      expect(rect.top, greaterThanOrEqualTo(0));
    });

    testWidgets('remains visible after scrolling the upper content', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject((_) {}));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      final rect = tester.getRect(
        find.widgetWithText(FilledButton, 'Start Game'),
      );
      expect(find.widgetWithText(FilledButton, 'Start Game'), findsOneWidget);
      expect(rect.bottom, lessThanOrEqualTo(740));
    });

    testWidgets(
      'scroll content is not covered by the fixed bottom action area',
      (tester) async {
        await tester.pumpWidget(buildSubject((_) {}));
        await tester.pumpAndSettle();

        // Scroll the last scrollable item into view first - it may start
        // out laid out below the (unclipped) viewport.
        await tester.ensureVisible(find.text('Statistics'));
        await tester.pumpAndSettle();

        final statisticsBottom = tester.getRect(find.text('Statistics')).bottom;
        final startGameTop = tester
            .getRect(find.widgetWithText(FilledButton, 'Start Game'))
            .top;
        expect(statisticsBottom, lessThanOrEqualTo(startGameTop));
      },
    );

    testWidgets('adds extra bottom inset when the safe area requires it', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject((_) {}));
      await tester.pumpAndSettle();
      final gapWithoutInset =
          740 -
          tester
              .getRect(find.widgetWithText(FilledButton, 'Start Game'))
              .bottom;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: buildSubject((_) {}),
        ),
      );
      await tester.pumpAndSettle();
      final gapWithInset =
          740 -
          tester
              .getRect(find.widgetWithText(FilledButton, 'Start Game'))
              .bottom;

      expect(gapWithInset, greaterThan(gapWithoutInset));
    });

    testWidgets('rapid taps invoke onStartGame only once', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(buildSubject((_) => callCount++));

      await tester.tap(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });

    testWidgets('does not overflow in a landscape aspect ratio', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(740, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject((_) {}));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(FilledButton, 'Start Game'), findsOneWidget);
    });
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

    testWidgets(
      'shows only the selected difficulty description, not the other two',
      (tester) async {
        await tester.pumpWidget(buildSubject((_) {}));

        // Medium is selected by default.
        expect(
          find.textContaining('Balanced everyday vocabulary'),
          findsOneWidget,
        );
        expect(find.textContaining('Familiar, common words'), findsNothing);
        expect(find.textContaining('Less common, trickier'), findsNothing);
      },
    );

    testWidgets('tapping Easy shows the Easy description', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));

      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Familiar, common words'), findsOneWidget);
      expect(find.textContaining('Balanced everyday vocabulary'), findsNothing);
      expect(find.textContaining('Less common, trickier'), findsNothing);
    });

    testWidgets('tapping Medium shows the Medium description', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));

      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Balanced everyday vocabulary'),
        findsOneWidget,
      );
      expect(find.textContaining('Familiar, common words'), findsNothing);
      expect(find.textContaining('Less common, trickier'), findsNothing);
    });

    testWidgets('tapping Hard shows the Hard description', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));

      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Less common, trickier'), findsOneWidget);
      expect(find.textContaining('Familiar, common words'), findsNothing);
      expect(find.textContaining('Balanced everyday vocabulary'), findsNothing);
    });

    testWidgets(
      'the selected difficulty has a semantic selected state distinct from '
      'the unselected ones',
      (tester) async {
        final semanticsHandle = tester.ensureSemantics();
        await tester.pumpWidget(buildSubject((_) {}));

        expect(
          tester
              .getSemantics(find.text('Medium'))
              .getSemanticsData()
              .flagsCollection
              .isSelected
              .toBoolOrNull(),
          isTrue,
        );
        expect(
          tester
              .getSemantics(find.text('Easy'))
              .getSemanticsData()
              .flagsCollection
              .isSelected
              .toBoolOrNull(),
          isNot(isTrue),
        );

        semanticsHandle.dispose();
      },
    );

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

  group('compact layout', () {
    testWidgets(
      'does not overflow at a typical Android phone size (Light theme)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 851));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject((_) {}, theme: ThemeData.light()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'does not overflow at a typical Android phone size (Dark theme)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 851));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject((_) {}, theme: ThemeData.dark()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the Start Game action remains usable through scrolling at a large '
      'text scale',
      (tester) async {
        var callCount = 0;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
            child: buildSubject((_) => callCount++),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start Game'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(callCount, 1);
      },
    );
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

  group('Milestone 16: onDifficultySelected', () {
    testWidgets('is invoked with the newly-chosen difficulty', (tester) async {
      DifficultyOption? selected;
      await tester.pumpWidget(
        buildSubject(
          (_) {},
          onDifficultySelected: (option) => selected = option,
        ),
      );

      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();

      expect(selected, DifficultyOption.hard);
    });

    testWidgets('is not invoked just from building the screen', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        buildSubject((_) {}, onDifficultySelected: (_) => callCount++),
      );

      expect(callCount, 0);
    });

    testWidgets('works normally when left unset', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}));

      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Milestone 18: streak summary', () {
    testWidgets('shows the current streak with friendly zero-streak copy', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_) {}, currentStreak: 0));
      expect(find.text('0-day streak'), findsOneWidget);
      // Never framed as an error/warning: no "broken" or negative wording.
      expect(find.textContaining('lost'), findsNothing);
      expect(find.textContaining('broken'), findsNothing);
    });

    testWidgets('shows a non-zero current streak', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}, currentStreak: 4));
      expect(find.text('4-day streak'), findsOneWidget);
    });

    testWidgets(
      'shows the longest streak less prominently, as "Best: N days"',
      (tester) async {
        await tester.pumpWidget(
          buildSubject((_) {}, currentStreak: 1, longestStreak: 8),
        );
        expect(find.text('Best: 8 days'), findsOneWidget);
      },
    );

    testWidgets('uses singular wording for a 1-day best streak', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject((_) {}, currentStreak: 1, longestStreak: 1),
      );
      expect(find.text('Best: 1 day'), findsOneWidget);
    });

    testWidgets('exposes streak information through semantics', (tester) async {
      await tester.pumpWidget(
        buildSubject((_) {}, currentStreak: 4, longestStreak: 8),
      );
      expect(
        find.bySemanticsLabel(RegExp('4-day streak.*Best: 8 days')),
        findsOneWidget,
      );
    });
  });

  group('Milestone 18: Daily Challenge card', () {
    testWidgets('is visible with the given date label', (tester) async {
      await tester.pumpWidget(
        buildSubject((_) {}, dailyChallengeDateLabel: '18 July 2026'),
      );
      expect(find.text('Daily Challenge'), findsOneWidget);
      expect(find.text('18 July 2026'), findsOneWidget);
    });

    testWidgets('shows "Not played" before completion', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (_) {},
          dailyChallengeStatus: DailyChallengeCardStatus.notPlayed,
        ),
      );
      expect(find.text('Not played'), findsOneWidget);
    });

    testWidgets('shows "Completed · Won" after a win', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (_) {},
          dailyChallengeStatus: DailyChallengeCardStatus.completedWon,
        ),
      );
      expect(find.text('Completed · Won'), findsOneWidget);
    });

    testWidgets('shows "Completed · Not solved" after a loss', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (_) {},
          dailyChallengeStatus: DailyChallengeCardStatus.completedNotSolved,
        ),
      );
      expect(find.text('Completed · Not solved'), findsOneWidget);
    });

    testWidgets('tapping the card invokes onOpenDailyChallenge exactly once', (
      tester,
    ) async {
      var callCount = 0;
      await tester.pumpWidget(
        buildSubject((_) {}, onOpenDailyChallenge: () => callCount++),
      );

      await tester.tap(find.text('Daily Challenge'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });

    testWidgets('does not overflow on a narrow screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildSubject(
          (_) {},
          currentStreak: 12,
          longestStreak: 34,
          dailyChallengeStatus: DailyChallengeCardStatus.completedNotSolved,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow under large text scaling', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: buildSubject(
            (_) {},
            currentStreak: 12,
            longestStreak: 34,
            dailyChallengeStatus: DailyChallengeCardStatus.completedWon,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Milestone 21: Share Streak', () {
    testWidgets('the Share Streak button is hidden when current streak is 0', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject((_) {}, currentStreak: 0));

      expect(find.bySemanticsLabel('Share streak'), findsNothing);
    });

    testWidgets('the Share Streak button appears when current streak is '
        'at least 1', (tester) async {
      await tester.pumpWidget(buildSubject((_) {}, currentStreak: 1));

      expect(find.bySemanticsLabel('Share streak'), findsOneWidget);
    });

    testWidgets(
      'tapping Share Streak opens the preview and shares the streak card',
      (tester) async {
        final renderer = FakeShareCardRenderer();
        final service = FakeShareCardService();

        await tester.pumpWidget(
          buildSubject(
            (_) {},
            currentStreak: 7,
            shareCardRenderer: renderer,
            shareCardService: service,
          ),
        );

        await tester.tap(find.bySemanticsLabel('Share streak'));
        await pumpForPreviewToOpen(tester);
        expect(find.text('Share preview'), findsOneWidget);

        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();

        expect(service.calls, hasLength(1));
        final call = service.calls.single;
        expect(call.fileName, 'cow-bull-quest-streak-7-days.png');
        expect(
          call.caption,
          'Cow Bull Quest\nI reached a 7-day streak.\n'
          "What's your biggest streak?",
        );
      },
    );

    testWidgets('sharing the streak does not change the displayed streak', (
      tester,
    ) async {
      final service = FakeShareCardService();
      await tester.pumpWidget(
        buildSubject((_) {}, currentStreak: 3, shareCardService: service),
      );

      await tester.tap(find.bySemanticsLabel('Share streak'));
      await pumpForPreviewToOpen(tester);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(find.textContaining('3-day streak'), findsOneWidget);
    });
  });
}
