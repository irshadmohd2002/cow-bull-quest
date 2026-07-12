import 'package:cowbullgame/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(ValueChanged<int> onStartGame) {
    return MaterialApp(home: HomeScreen(onStartGame: onStartGame));
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
