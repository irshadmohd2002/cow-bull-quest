import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:cowbullgame/features/game/services/hint_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = HintPolicy();

  group('HintPolicy.maxHints', () {
    test('Easy allows exactly one hint', () {
      expect(policy.maxHints(GameDifficulty.easy), 1);
    });

    test('Medium (common) allows exactly one hint', () {
      expect(policy.maxHints(GameDifficulty.common), 1);
    });

    test('Hard allows exactly two hints', () {
      expect(policy.maxHints(GameDifficulty.hard), 2);
    });
  });

  group('HintPolicy.costFor', () {
    test('Easy always costs 20 coins', () {
      expect(policy.costFor(GameDifficulty.easy, 0), hintCoinCost);
    });

    test('Medium always costs 20 coins', () {
      expect(policy.costFor(GameDifficulty.common, 0), hintCoinCost);
    });

    test('Hard\'s first hint (0 used so far) is free', () {
      expect(policy.costFor(GameDifficulty.hard, 0), 0);
    });

    test('Hard\'s second hint (1 used so far) costs 20 coins', () {
      expect(policy.costFor(GameDifficulty.hard, 1), hintCoinCost);
    });

    test('hintCoinCost is exactly 20', () {
      expect(hintCoinCost, 20);
    });
  });
}
