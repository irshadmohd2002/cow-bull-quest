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
}
