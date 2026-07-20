import 'package:cowbullgame/models/streak_share_data.dart';
import 'package:cowbullgame/widgets/share_cards/streak_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Center(child: child));

  testWidgets('contains the exact streak count and milestone subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(StreakShareCard(data: StreakShareData(currentStreak: 7))),
    );
    await tester.pump();

    expect(find.text('STREAK'), findsOneWidget);
    expect(find.text('7 DAYS STREAK'), findsOneWidget);
    expect(find.text('1 WEEK'), findsOneWidget);
  });

  testWidgets('uses singular "1 DAY STREAK" for a 1-day streak', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(StreakShareCard(data: StreakShareData(currentStreak: 1))),
    );
    await tester.pump();

    expect(find.text('1 DAY STREAK'), findsOneWidget);
  });

  testWidgets('omits the milestone subtitle for a non-milestone streak', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(StreakShareCard(data: StreakShareData(currentStreak: 10))),
    );
    await tester.pump();

    expect(find.text('10 DAYS STREAK'), findsOneWidget);
    expect(find.text('1 WEEK'), findsNothing);
    expect(find.text('1 MONTH'), findsNothing);
  });

  testWidgets('footer is the exact required question', (tester) async {
    await tester.pumpWidget(
      host(StreakShareCard(data: StreakShareData(currentStreak: 30))),
    );
    await tester.pump();

    expect(find.text("What's your biggest streak?"), findsOneWidget);
  });

  testWidgets('never mentions coins, attempts, hints, or generic copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(StreakShareCard(data: StreakShareData(currentStreak: 30))),
    );
    await tester.pump();

    expect(find.textContaining('coin'), findsNothing);
    expect(find.textContaining('attempt'), findsNothing);
    expect(find.textContaining('hint'), findsNothing);
    expect(find.textContaining('Played daily'), findsNothing);
    expect(find.textContaining('Keep it going'), findsNothing);
  });

  testWidgets('does not overflow for a 3-digit streak', (tester) async {
    await tester.pumpWidget(
      host(StreakShareCard(data: StreakShareData(currentStreak: 365))),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('365 DAYS STREAK'), findsOneWidget);
    expect(find.text('1 YEAR'), findsOneWidget);
  });
}
