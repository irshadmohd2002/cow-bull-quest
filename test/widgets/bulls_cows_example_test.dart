import 'package:cowbullgame/theme/app_theme.dart';
import 'package:cowbullgame/widgets/bulls_cows_example.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({ThemeData? theme}) {
    return MaterialApp(
      theme: theme,
      home: const Scaffold(body: BullsCowsExample()),
    );
  }

  testWidgets('shows the secret word and guess word', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.textContaining('PLAN'), findsWidgets);
    expect(find.textContaining('LAWN'), findsWidgets);
  });

  testWidgets('shows the Bull, Cow, and Not in word labels', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.text('Bull'), findsOneWidget);
    expect(find.text('Cow'), findsNWidgets(2));
    expect(find.text('Not in word'), findsOneWidget);
  });

  testWidgets('conveys each letter status through a distinct icon, not just '
      'color', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    expect(find.byIcon(Icons.sync_alt), findsNWidgets(2));
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
  });

  testWidgets('exposes a single, non-redundant semantics label describing '
      'every letter', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(
      find.bySemanticsLabel(
        RegExp(r'secret word PLAN, guess LAWN.*1 bull, 2 cows', dotAll: true),
      ),
      findsOneWidget,
    );
  });

  testWidgets('never mentions a real word-list or repository', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.textContaining('WordRepository'), findsNothing);
  });

  testWidgets('renders without exceptions in dark theme', (tester) async {
    await tester.pumpWidget(buildSubject(theme: AppTheme.dark));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without exceptions in light theme', (tester) async {
    await tester.pumpWidget(buildSubject(theme: AppTheme.light));
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow under large text scaling when hosted in a '
      'scrollable screen — the same context every real caller (Rules, '
      'Onboarding) embeds it in', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: BullsCowsExample()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(300, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow at a typical phone screenshot size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('the four L/A/W/N tiles stay on one row', () {
    /// The four tiles are the only [Container]s [BullsCowsExample] renders
    /// (the rest of the tree is Card/Padding/Column/Row/Text/Icon), so
    /// scoping by type is enough to find them in guess order: L, A, W, N.
    Finder tileFinder() => find.descendant(
      of: find.byType(BullsCowsExample),
      matching: find.byType(Container),
    );

    testWidgets('renders exactly one tile per letter', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(tileFinder(), findsNWidgets(4));
    });

    testWidgets(
      'all four tile tops and bottoms line up, and none (in particular N, '
      'the previously-wrapping tile) sits below the others',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final tiles = tileFinder();
        final rects = [for (var i = 0; i < 4; i++) tester.getRect(tiles.at(i))];

        for (final rect in rects.skip(1)) {
          expect(rect.top, closeTo(rects.first.top, 0.5));
          expect(rect.bottom, closeTo(rects.first.bottom, 0.5));
        }
      },
    );

    testWidgets('all four tiles are equal width', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final tiles = tileFinder();
      final widths = [
        for (var i = 0; i < 4; i++) tester.getRect(tiles.at(i)).width,
      ];

      for (final width in widths.skip(1)) {
        expect(width, closeTo(widths.first, 0.5));
      }
    });

    testWidgets('tiles are horizontally ordered L, A, W, N left to right', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final tiles = tileFinder();
      final lefts = [
        for (var i = 0; i < 4; i++) tester.getRect(tiles.at(i)).left,
      ];

      expect(lefts[0], lessThan(lefts[1]));
      expect(lefts[1], lessThan(lefts[2]));
      expect(lefts[2], lessThan(lefts[3]));
    });

    testWidgets('stays on one row at a narrow phone width', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final tiles = tileFinder();
      final tops = [
        for (var i = 0; i < 4; i++) tester.getRect(tiles.at(i)).top,
      ];
      for (final top in tops.skip(1)) {
        expect(top, closeTo(tops.first, 0.5));
      }
    });

    testWidgets('stays on one row at a moderately large text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: BullsCowsExample()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final tiles = tileFinder();
      final tops = [
        for (var i = 0; i < 4; i++) tester.getRect(tiles.at(i)).top,
      ];
      for (final top in tops.skip(1)) {
        expect(top, closeTo(tops.first, 0.5));
      }
    });
  });
}
