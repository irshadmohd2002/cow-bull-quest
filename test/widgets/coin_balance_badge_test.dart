import 'package:cowbullgame/theme/app_theme.dart';
import 'package:cowbullgame/widgets/coin_balance_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(int balance, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(body: CoinBalanceBadge(balance: balance)),
    );
  }

  testWidgets('shows the balance as text', (tester) async {
    await tester.pumpWidget(buildSubject(150));
    expect(find.text('150'), findsOneWidget);
  });

  testWidgets('shows a coin icon', (tester) async {
    await tester.pumpWidget(buildSubject(100));
    expect(find.byIcon(Icons.monetization_on), findsOneWidget);
  });

  testWidgets('has an accessible label stating the balance', (tester) async {
    await tester.pumpWidget(buildSubject(100));
    expect(find.bySemanticsLabel('100 coins'), findsOneWidget);
  });

  testWidgets('updates when the balance changes', (tester) async {
    await tester.pumpWidget(buildSubject(100));
    expect(find.text('100'), findsOneWidget);

    await tester.pumpWidget(buildSubject(80));
    expect(find.text('80'), findsOneWidget);
    expect(find.text('100'), findsNothing);
  });

  testWidgets('renders without exceptions in dark theme', (tester) async {
    await tester.pumpWidget(buildSubject(100, theme: AppTheme.dark));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('renders without exceptions in light theme', (tester) async {
    await tester.pumpWidget(buildSubject(100, theme: AppTheme.light));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('does not throw under large text scaling', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: buildSubject(100),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('Milestone 15: spend feedback', () {
    testWidgets('shows a transient "-20" label when the balance decreases '
        'by 20', (tester) async {
      await tester.pumpWidget(buildSubject(100));
      await tester.pumpWidget(buildSubject(80));
      await tester.pump();

      expect(find.text('-20'), findsOneWidget);
    });

    testWidgets('the transient label fades out and the balance stays '
        'accurate once animations settle', (tester) async {
      await tester.pumpWidget(buildSubject(100));
      await tester.pumpWidget(buildSubject(80));
      await tester.pumpAndSettle();

      expect(find.text('80'), findsOneWidget);
      final opacityFinder = find.ancestor(
        of: find.text('-20'),
        matching: find.byType(Opacity),
      );
      final opacity = tester.widget<Opacity>(opacityFinder);
      expect(opacity.opacity, 0.0);
    });

    testWidgets('shows no transient label when the balance is unchanged '
        'across a rebuild', (tester) async {
      await tester.pumpWidget(buildSubject(100));
      await tester.pumpWidget(buildSubject(100));
      await tester.pump();

      expect(find.textContaining('-'), findsNothing);
    });

    testWidgets('shows no transient label on the very first build', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(80));
      await tester.pump();

      expect(find.textContaining('-'), findsNothing);
    });

    testWidgets('a cancelled hint (no balance change) shows no transient '
        'label', (tester) async {
      await tester.pumpWidget(buildSubject(100));
      await tester.pumpWidget(buildSubject(100));
      await tester.pumpAndSettle();

      expect(find.textContaining('-'), findsNothing);
      expect(find.text('100'), findsOneWidget);
    });
  });
}
