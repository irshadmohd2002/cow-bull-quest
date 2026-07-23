import 'package:cowbullgame/theme/app_theme.dart';
import 'package:cowbullgame/widgets/cow_head_icon.dart';
import 'package:cowbullgame/widgets/guess_result_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(
    List<Widget> badges, {
    double width = 400,
    TextScaler textScaler = TextScaler.noScaling,
    ThemeData? theme,
  }) {
    return MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: width,
            // Each child gets its own Flexible, mirroring how
            // GuessHistoryTile actually hosts these badges — a bounded
            // width lets a badge's internal FittedBox shrink it instead of
            // overflowing when space is tight.
            child: Row(
              children: [for (final badge in badges) Flexible(child: badge)],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Bull badge shows a target icon', (tester) async {
    await tester.pumpWidget(
      buildSubject([
        const GuessResultBadge(type: GuessResultBadgeType.bull, count: 2),
      ]),
    );

    expect(find.byIcon(Icons.gps_fixed_rounded), findsOneWidget);
  });

  testWidgets('Cow badge shows a cow-head icon, not compare arrows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject([
        const GuessResultBadge(type: GuessResultBadgeType.cow, count: 2),
      ]),
    );

    expect(find.byType(CowHeadIcon), findsOneWidget);
    expect(find.byIcon(Icons.sync_alt), findsNothing);
  });

  testWidgets('Bull label is singular at a count of 1', (tester) async {
    await tester.pumpWidget(
      buildSubject([
        const GuessResultBadge(type: GuessResultBadgeType.bull, count: 1),
      ]),
    );

    expect(find.text('Bull 1'), findsOneWidget);
  });

  testWidgets('Bull label is plural at 0 and above 1', (tester) async {
    await tester.pumpWidget(
      buildSubject([
        const GuessResultBadge(type: GuessResultBadgeType.bull, count: 0),
        const GuessResultBadge(type: GuessResultBadgeType.bull, count: 3),
      ]),
    );

    expect(find.text('Bulls 0'), findsOneWidget);
    expect(find.text('Bulls 3'), findsOneWidget);
  });

  testWidgets('Cow label is singular at a count of 1', (tester) async {
    await tester.pumpWidget(
      buildSubject([
        const GuessResultBadge(type: GuessResultBadgeType.cow, count: 1),
      ]),
    );

    expect(find.text('Cow 1'), findsOneWidget);
  });

  testWidgets('Cow label is plural at 0 and above 1', (tester) async {
    await tester.pumpWidget(
      buildSubject([
        const GuessResultBadge(type: GuessResultBadgeType.cow, count: 0),
        const GuessResultBadge(type: GuessResultBadgeType.cow, count: 3),
      ]),
    );

    expect(find.text('Cows 0'), findsOneWidget);
    expect(find.text('Cows 3'), findsOneWidget);
  });

  testWidgets('label and count stay on a single line', (tester) async {
    await tester.pumpWidget(
      buildSubject([
        const GuessResultBadge(type: GuessResultBadgeType.bull, count: 12),
      ]),
    );

    final text = tester.widget<Text>(find.text('Bulls 12'));
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
  });

  testWidgets('exposes a meaningful semantic label, e.g. "2 Bulls"/"1 Cow"', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject([
        const GuessResultBadge(type: GuessResultBadgeType.bull, count: 2),
        const GuessResultBadge(type: GuessResultBadgeType.cow, count: 1),
      ]),
    );

    expect(find.bySemanticsLabel('2 Bulls'), findsOneWidget);
    expect(find.bySemanticsLabel('1 Cow'), findsOneWidget);
  });

  testWidgets('both badges render together at normal phone width without '
      'overflowing', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildSubject([
        const GuessResultBadge(type: GuessResultBadgeType.bull, count: 2),
        const SizedBox(width: 8),
        const GuessResultBadge(type: GuessResultBadgeType.cow, count: 1),
      ]),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(GuessResultBadge), findsNWidgets(2));
  });

  testWidgets('does not overflow on a narrow screen at a large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        [
          const GuessResultBadge(type: GuessResultBadgeType.bull, count: 4),
          const SizedBox(width: 8),
          const GuessResultBadge(type: GuessResultBadgeType.cow, count: 0),
        ],
        width: 220,
        textScaler: const TextScaler.linear(2.5),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the Bull and Cow icons differ (not relying on color alone)', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject([
        const GuessResultBadge(type: GuessResultBadgeType.bull, count: 1),
        const GuessResultBadge(type: GuessResultBadgeType.cow, count: 1),
      ]),
    );

    expect(find.byIcon(Icons.gps_fixed_rounded), findsOneWidget);
    expect(find.byType(CowHeadIcon), findsOneWidget);
  });

  testWidgets('renders without exceptions in dark and light themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      await tester.pumpWidget(
        buildSubject([
          const GuessResultBadge(type: GuessResultBadgeType.bull, count: 2),
          const GuessResultBadge(type: GuessResultBadgeType.cow, count: 1),
        ], theme: theme),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
