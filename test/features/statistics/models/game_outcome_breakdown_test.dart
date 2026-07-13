import 'package:cowbullgame/features/statistics/models/game_outcome_breakdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameOutcomeBreakdown validation', () {
    test('rejects a negative totalGames', () {
      expect(
        () => GameOutcomeBreakdown(totalGames: -1, wins: 0),
        throwsArgumentError,
      );
    });

    test('rejects a negative wins', () {
      expect(
        () => GameOutcomeBreakdown(totalGames: 1, wins: -1),
        throwsArgumentError,
      );
    });

    test('rejects wins greater than totalGames', () {
      expect(
        () => GameOutcomeBreakdown(totalGames: 1, wins: 2),
        throwsArgumentError,
      );
    });
  });

  group('GameOutcomeBreakdown derived values', () {
    test('winRate is 0 for an empty breakdown, never NaN', () {
      expect(GameOutcomeBreakdown.empty.winRate, 0);
    });

    test('losses is derived as totalGames - wins', () {
      final breakdown = GameOutcomeBreakdown(totalGames: 5, wins: 2);
      expect(breakdown.losses, 3);
    });

    test('winRate reflects wins over totalGames', () {
      final breakdown = GameOutcomeBreakdown(totalGames: 4, wins: 1);
      expect(breakdown.winRate, 0.25);
    });
  });

  group('GameOutcomeBreakdown JSON round-trip', () {
    test('fromJson(toJson()) reconstructs an equal breakdown', () {
      final breakdown = GameOutcomeBreakdown(totalGames: 6, wins: 4);
      final restored = GameOutcomeBreakdown.fromJson(breakdown.toJson());
      expect(restored, breakdown);
    });

    test('fromJson rejects a missing field', () {
      expect(
        () => GameOutcomeBreakdown.fromJson({'wins': 1}),
        throwsFormatException,
      );
    });

    test('fromJson rejects a wrong-typed field', () {
      expect(
        () => GameOutcomeBreakdown.fromJson({'totalGames': '3', 'wins': 1}),
        throwsFormatException,
      );
    });
  });
}
