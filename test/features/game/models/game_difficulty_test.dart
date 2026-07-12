import 'package:cowbullgame/features/game/models/game_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('has exactly three values: easy, common, hard', () {
    expect(GameDifficulty.values, [
      GameDifficulty.easy,
      GameDifficulty.common,
      GameDifficulty.hard,
    ]);
  });

  test('values have natural (enum) value equality', () {
    expect(GameDifficulty.easy == GameDifficulty.easy, isTrue);
    expect(GameDifficulty.easy == GameDifficulty.hard, isFalse);
  });
}
