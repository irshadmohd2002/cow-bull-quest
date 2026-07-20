import 'package:cowbullgame/models/normal_win_share_data.dart';
import 'package:cowbullgame/widgets/share_cards/normal_win_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Center(child: child));

  testWidgets(
    'renders logo/name, SOLVED, difficulty, attempts, hints, and coins',
    (tester) async {
      final data = NormalWinShareData(
        difficultyLabel: 'Medium',
        attemptsUsed: 4,
        maxAttempts: 10,
        hintsUsed: 1,
        coinsEarned: 20,
      );
      await tester.pumpWidget(host(NormalWinShareCard(data: data)));
      await tester.pump();

      expect(find.text('COW BULL QUEST'), findsOneWidget);
      expect(find.text('SOLVED'), findsOneWidget);
      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('Solved in 4/10 attempts.'), findsOneWidget);
      expect(find.text('1 hint used.'), findsOneWidget);
      expect(find.text('+20 coins'), findsOneWidget);
      expect(find.text('Can you solve it too?'), findsOneWidget);
    },
  );

  testWidgets('omits the coins row when coinsEarned is 0', (tester) async {
    final data = NormalWinShareData(
      difficultyLabel: 'Easy',
      attemptsUsed: 5,
      maxAttempts: 10,
      hintsUsed: 0,
      coinsEarned: 0,
    );
    await tester.pumpWidget(host(NormalWinShareCard(data: data)));
    await tester.pump();

    expect(find.textContaining('coins'), findsNothing);
    expect(find.text('No hints used.'), findsOneWidget);
  });

  testWidgets('never renders a secret word or guess content', (tester) async {
    final data = NormalWinShareData(
      difficultyLabel: 'Hard',
      attemptsUsed: 3,
      maxAttempts: 10,
      hintsUsed: 0,
      coinsEarned: 25,
    );
    await tester.pumpWidget(host(NormalWinShareCard(data: data)));
    await tester.pump();

    expect(find.textContaining('secret', findRichText: true), findsNothing);
    expect(find.textContaining('Bulls'), findsNothing);
    expect(find.textContaining('Cows'), findsNothing);
  });

  testWidgets('does not overflow at 10/10 attempts and 2 hints', (
    tester,
  ) async {
    final data = NormalWinShareData(
      difficultyLabel: 'Hard',
      attemptsUsed: 10,
      maxAttempts: 10,
      hintsUsed: 2,
      coinsEarned: 999,
    );
    await tester.pumpWidget(host(NormalWinShareCard(data: data)));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
