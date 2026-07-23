import 'package:cowbullgame/features/onboarding/presentation/onboarding_screen.dart';
import 'package:cowbullgame/theme/app_theme.dart';
import 'package:cowbullgame/widgets/app_bullet_item.dart';
import 'package:cowbullgame/widgets/bulls_cows_example.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({VoidCallback? onDone}) {
    return MaterialApp(home: OnboardingScreen(onDone: onDone ?? () {}));
  }

  testWidgets('shows the first page on launch', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.text('Guess the Secret Word'), findsOneWidget);
  });

  testWidgets('Back is not shown on the first page', (tester) async {
    await tester.pumpWidget(buildSubject());
    final backButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Back'),
    );
    expect(backButton.onPressed, isNull);
  });

  testWidgets('Next advances through every page in order', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Guess the Secret Word'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Bulls and Cows'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Difficulty and Hints'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Track Your Progress'), findsOneWidget);
  });

  testWidgets('there are exactly 4 pages', (tester) async {
    await tester.pumpWidget(buildSubject());

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    // On the 4th (last) page, Next is replaced with Finish.
    expect(find.text('Next'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('Back returns to the previous page', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Bulls and Cows'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Guess the Secret Word'), findsOneWidget);
  });

  testWidgets('Skip invokes onDone immediately from the first page', (
    tester,
  ) async {
    var doneCount = 0;
    await tester.pumpWidget(buildSubject(onDone: () => doneCount++));

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(doneCount, 1);
  });

  testWidgets('Skip is not shown on the last page', (tester) async {
    await tester.pumpWidget(buildSubject());

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('Finish invokes onDone from the last page', (tester) async {
    var doneCount = 0;
    await tester.pumpWidget(buildSubject(onDone: () => doneCount++));

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(doneCount, 1);
  });

  testWidgets('the page indicator reflects the current page', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.bySemanticsLabel('Page 1 of 4'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Page 2 of 4'), findsOneWidget);
  });

  testWidgets('the Bulls and Cows page shows the visual example', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.byType(BullsCowsExample), findsOneWidget);
  });

  testWidgets('does not overflow under large text scaling on any page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
        child: buildSubject(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders without exceptions in dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnboardingScreen(onDone: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without exceptions in light theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OnboardingScreen(onDone: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('bullet alignment', () {
    testWidgets('every bullet on the first page is rendered as an '
        'AppBulletItem', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(AppBulletItem), findsNWidgets(3));
    });

    testWidgets('each bullet exposes exactly one semantics label for its '
        'sentence — the decorative dot is never announced separately', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.bySemanticsLabel('Guess the hidden 4-letter word.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('You have 10 attempts.'), findsOneWidget);
    });

    testWidgets(
      'on the multi-line "Difficulty and Hints" page, each bullet dot '
      'aligns with its first line (stays above the paragraph midpoint, not '
      'centered against it)',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Difficulty and Hints'), findsOneWidget);

        final dots = find.byIcon(Icons.circle);
        final texts = find.byType(AppBulletItem);
        expect(texts, findsWidgets);

        for (var i = 0; i < tester.widgetList(dots).length; i++) {
          final dotRect = tester.getRect(dots.at(i));
          final itemRect = tester.getRect(texts.at(i));
          expect(dotRect.center.dy, lessThan(itemRect.center.dy));
        }
      },
    );

    testWidgets(
      'does not overflow on every onboarding page at a narrow width and a '
      'large text scale together',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: buildSubject(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
