import 'package:cowbullgame/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(
    ValueChanged<int> onStartGame, {
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
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.text('Bulls & Cows'), findsWidgets);
  });

  testWidgets('briefly explains the game', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.textContaining('bull'), findsWidgets);
    expect(find.textContaining('cow'), findsWidgets);
  });

  testWidgets('shows 4, 5, and 6 letter options', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.text('4 letters'), findsOneWidget);
    expect(find.text('5 letters'), findsOneWidget);
    expect(find.text('6 letters'), findsOneWidget);
  });

  testWidgets('defaults to the 4-letter option selected', (tester) async {
    await tester.pumpWidget(buildSubject((_) {}));
    final segmentedButton = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(segmentedButton.selected, {4});
  });

  testWidgets('selecting an option updates the visible selection', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_) {}));

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
      buildSubject((wordLength) => startedWordLength = wordLength),
    );

    await tester.tap(find.text('5 letters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(startedWordLength, 5);
  });

  testWidgets('starting without changing the selection uses the default '
      'option', (tester) async {
    int? startedWordLength;
    await tester.pumpWidget(
      buildSubject((wordLength) => startedWordLength = wordLength),
    );

    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(startedWordLength, 4);
  });

  testWidgets('has a semantic label for the word length selection', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_) {}));
    expect(find.bySemanticsLabel('Word length selection'), findsOneWidget);
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

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('starting the game invokes onStartGame exactly once', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(buildSubject((_) => callCount++));

    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
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
}
