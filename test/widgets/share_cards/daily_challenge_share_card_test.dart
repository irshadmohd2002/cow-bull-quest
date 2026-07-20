import 'package:cowbullgame/models/daily_challenge_share_data.dart';
import 'package:cowbullgame/widgets/share_cards/daily_challenge_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Center(child: child));

  testWidgets(
    'renders label, date, SOLVED, attempts, hints, coins, and streak',
    (tester) async {
      final data = DailyChallengeShareData(
        dateLabel: '20 JULY 2026',
        attemptsUsed: 4,
        maxAttempts: 10,
        hintsUsed: 0,
        coinsEarned: 25,
        currentStreak: 7,
      );
      await tester.pumpWidget(host(DailyChallengeShareCard(data: data)));
      await tester.pump();

      expect(find.text('DAILY CHALLENGE'), findsOneWidget);
      expect(find.text('20 JULY 2026'), findsOneWidget);
      expect(find.text('SOLVED'), findsOneWidget);
      expect(find.text('Solved in 4/10 attempts.'), findsOneWidget);
      expect(find.text('No hints used.'), findsOneWidget);
      expect(find.text('+25 coins'), findsOneWidget);
      expect(find.text('7-day streak'), findsOneWidget);
      expect(find.text("Can you beat today's challenge?"), findsOneWidget);
    },
  );

  testWidgets('never renders a secret word or guess content', (tester) async {
    final data = DailyChallengeShareData(
      dateLabel: '1 JANUARY 2026',
      attemptsUsed: 2,
      maxAttempts: 10,
      hintsUsed: 0,
      coinsEarned: 25,
      currentStreak: 1,
    );
    await tester.pumpWidget(host(DailyChallengeShareCard(data: data)));
    await tester.pump();

    expect(find.textContaining('Bulls'), findsNothing);
    expect(find.textContaining('Cows'), findsNothing);
  });

  testWidgets('does not overflow with a long month name and 3-digit coins', (
    tester,
  ) async {
    final data = DailyChallengeShareData(
      dateLabel: '30 SEPTEMBER 2026',
      attemptsUsed: 10,
      maxAttempts: 10,
      hintsUsed: 2,
      coinsEarned: 999,
      currentStreak: 365,
    );
    await tester.pumpWidget(host(DailyChallengeShareCard(data: data)));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
