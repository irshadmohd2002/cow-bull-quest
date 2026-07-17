import 'package:cowbullgame/features/game/controllers/game_controller_state.dart';
import 'package:cowbullgame/features/game/models/revealed_hint.dart';
import 'package:cowbullgame/features/game/presentation/widgets/hint_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    required HintAvailability availability,
    List<RevealedHint> revealedHints = const [],
    int coinBalance = 100,
    bool enabled = true,
    VoidCallback? onUseHint,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HintSection(
          availability: availability,
          revealedHints: revealedHints,
          coinBalance: coinBalance,
          enabled: enabled,
          onUseHint: onUseHint ?? () {},
        ),
      ),
    );
  }

  group('hintButtonLabel', () {
    test('Easy/Medium before use reads "Hint · 20 coins"', () {
      const availability = HintAvailability(
        canRequestHint: true,
        hintsUsed: 0,
        maxHints: 1,
        nextHintCost: 20,
      );
      expect(hintButtonLabel(availability), 'Hint · 20 coins');
    });

    test('Hard before first use reads "Free Hint"', () {
      const availability = HintAvailability(
        canRequestHint: true,
        hintsUsed: 0,
        maxHints: 2,
        nextHintCost: 0,
      );
      expect(hintButtonLabel(availability), 'Free Hint');
    });

    test('Hard before second use reads "Hint · 20 coins"', () {
      const availability = HintAvailability(
        canRequestHint: true,
        hintsUsed: 1,
        maxHints: 2,
        nextHintCost: 20,
      );
      expect(hintButtonLabel(availability), 'Hint · 20 coins');
    });

    test('after the limit reads "No hints remaining"', () {
      const availability = HintAvailability(
        canRequestHint: false,
        hintsUsed: 1,
        maxHints: 1,
        nextHintCost: 0,
      );
      expect(hintButtonLabel(availability), 'No hints remaining');
    });
  });

  group('HintSection button', () {
    testWidgets('shows the Easy/Medium paid-hint label', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: true,
            hintsUsed: 0,
            maxHints: 1,
            nextHintCost: 20,
          ),
        ),
      );
      expect(find.text('Hint · 20 coins'), findsOneWidget);
    });

    testWidgets('shows the Hard free-hint label', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: true,
            hintsUsed: 0,
            maxHints: 2,
            nextHintCost: 0,
          ),
        ),
      );
      expect(find.text('Free Hint'), findsOneWidget);
    });

    testWidgets('shows "No hints remaining" once exhausted', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: false,
            hintsUsed: 1,
            maxHints: 1,
            nextHintCost: 0,
          ),
          enabled: false,
        ),
      );
      expect(find.text('No hints remaining'), findsOneWidget);
    });

    testWidgets('tapping an enabled button invokes onUseHint', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: true,
            hintsUsed: 0,
            maxHints: 1,
            nextHintCost: 20,
          ),
          onUseHint: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(OutlinedButton));
      expect(tapped, isTrue);
    });

    testWidgets('a disabled button cannot be tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: false,
            hintsUsed: 1,
            maxHints: 1,
            nextHintCost: 0,
          ),
          enabled: false,
          onUseHint: () => tapped = true,
        ),
      );

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
      expect(tapped, isFalse);
    });

    testWidgets('has an accessible label for a free hint', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: true,
            hintsUsed: 0,
            maxHints: 2,
            nextHintCost: 0,
          ),
        ),
      );
      expect(find.bySemanticsLabel('Use free hint'), findsOneWidget);
    });
  });

  group('HintSection insufficient balance', () {
    testWidgets('shows guidance text when the balance is below the cost', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: true,
            hintsUsed: 0,
            maxHints: 1,
            nextHintCost: 20,
          ),
          coinBalance: 5,
          enabled: false,
        ),
      );
      expect(find.text('Not enough coins for a hint.'), findsOneWidget);
    });

    testWidgets('shows no guidance text when the balance is sufficient', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: true,
            hintsUsed: 0,
            maxHints: 1,
            nextHintCost: 20,
          ),
          coinBalance: 100,
        ),
      );
      expect(find.text('Not enough coins for a hint.'), findsNothing);
    });

    testWidgets('shows no guidance text for a free hint regardless of '
        'balance', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: true,
            hintsUsed: 0,
            maxHints: 2,
            nextHintCost: 0,
          ),
          coinBalance: 0,
        ),
      );
      expect(find.text('Not enough coins for a hint.'), findsNothing);
    });
  });

  group('HintSection revealed hints', () {
    testWidgets('shows the revealed letter and its position', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: true,
            hintsUsed: 1,
            maxHints: 2,
            nextHintCost: 20,
          ),
          revealedHints: const [RevealedHint(position: 1, letter: 'a')],
        ),
      );
      expect(find.text('The second letter is A.'), findsOneWidget);
    });

    testWidgets('shows every revealed hint, oldest first', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: false,
            hintsUsed: 2,
            maxHints: 2,
            nextHintCost: 0,
          ),
          revealedHints: const [
            RevealedHint(position: 0, letter: 'l'),
            RevealedHint(position: 1, letter: 'a'),
          ],
          enabled: false,
        ),
      );
      expect(find.text('The first letter is L.'), findsOneWidget);
      expect(find.text('The second letter is A.'), findsOneWidget);
    });

    testWidgets('shows no hint chips when none have been revealed', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: true,
            hintsUsed: 0,
            maxHints: 1,
            nextHintCost: 20,
          ),
        ),
      );
      expect(find.byIcon(Icons.lightbulb), findsNothing);
    });

    testWidgets('has an accessible "Hint:" label distinct from the visible '
        'text', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          availability: const HintAvailability(
            canRequestHint: true,
            hintsUsed: 1,
            maxHints: 2,
            nextHintCost: 20,
          ),
          revealedHints: const [RevealedHint(position: 0, letter: 'l')],
        ),
      );
      expect(
        find.bySemanticsLabel('Hint: The first letter is L.'),
        findsOneWidget,
      );
    });
  });
}
