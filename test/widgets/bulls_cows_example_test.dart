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
}
