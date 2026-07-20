import 'package:cowbullgame/models/normal_win_share_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NormalWinShareData', () {
    test('attemptsLabel formats "Solved in X/Y attempts"', () {
      final data = NormalWinShareData(
        difficultyLabel: 'Medium',
        attemptsUsed: 4,
        maxAttempts: 10,
        hintsUsed: 0,
        coinsEarned: 0,
      );
      expect(data.attemptsLabel, 'Solved in 4/10 attempts');
    });

    test('hintsLabel is "No hints used" for zero hints', () {
      final data = NormalWinShareData(
        difficultyLabel: 'Easy',
        attemptsUsed: 1,
        maxAttempts: 10,
        hintsUsed: 0,
        coinsEarned: 0,
      );
      expect(data.hintsLabel, 'No hints used');
    });

    test('hintsLabel is singular for exactly one hint', () {
      final data = NormalWinShareData(
        difficultyLabel: 'Easy',
        attemptsUsed: 1,
        maxAttempts: 10,
        hintsUsed: 1,
        coinsEarned: 0,
      );
      expect(data.hintsLabel, '1 hint used');
    });

    test('hintsLabel is plural for two or more hints', () {
      final data = NormalWinShareData(
        difficultyLabel: 'Easy',
        attemptsUsed: 1,
        maxAttempts: 10,
        hintsUsed: 2,
        coinsEarned: 0,
      );
      expect(data.hintsLabel, '2 hints used');
    });

    test('throws if attemptsUsed exceeds maxAttempts', () {
      expect(
        () => NormalWinShareData(
          difficultyLabel: 'Easy',
          attemptsUsed: 11,
          maxAttempts: 10,
          hintsUsed: 0,
          coinsEarned: 0,
        ),
        throwsArgumentError,
      );
    });

    test('throws for a negative coinsEarned', () {
      expect(
        () => NormalWinShareData(
          difficultyLabel: 'Easy',
          attemptsUsed: 1,
          maxAttempts: 10,
          hintsUsed: 0,
          coinsEarned: -1,
        ),
        throwsArgumentError,
      );
    });

    test('equality is value-based', () {
      NormalWinShareData build() => NormalWinShareData(
        difficultyLabel: 'Hard',
        attemptsUsed: 3,
        maxAttempts: 10,
        hintsUsed: 1,
        coinsEarned: 25,
      );
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });
  });
}
