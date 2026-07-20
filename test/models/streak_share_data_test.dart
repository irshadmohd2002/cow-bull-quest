import 'package:cowbullgame/models/streak_share_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakShareData', () {
    test('throws for a zero streak', () {
      expect(() => StreakShareData(currentStreak: 0), throwsArgumentError);
    });

    test('throws for a negative streak', () {
      expect(() => StreakShareData(currentStreak: -1), throwsArgumentError);
    });

    test('primaryLabel is singular for exactly one day', () {
      expect(StreakShareData(currentStreak: 1).primaryLabel, '1 DAY STREAK');
    });

    test('primaryLabel is plural for two or more days', () {
      expect(StreakShareData(currentStreak: 2).primaryLabel, '2 DAYS STREAK');
      expect(StreakShareData(currentStreak: 45).primaryLabel, '45 DAYS STREAK');
    });

    test('milestoneLabel for exact milestones', () {
      expect(StreakShareData(currentStreak: 7).milestoneLabel, '1 WEEK');
      expect(StreakShareData(currentStreak: 14).milestoneLabel, '2 WEEKS');
      expect(StreakShareData(currentStreak: 21).milestoneLabel, '3 WEEKS');
      expect(StreakShareData(currentStreak: 30).milestoneLabel, '1 MONTH');
      expect(StreakShareData(currentStreak: 60).milestoneLabel, '2 MONTHS');
      expect(StreakShareData(currentStreak: 90).milestoneLabel, '3 MONTHS');
      expect(StreakShareData(currentStreak: 180).milestoneLabel, '6 MONTHS');
      expect(StreakShareData(currentStreak: 365).milestoneLabel, '1 YEAR');
      expect(StreakShareData(currentStreak: 730).milestoneLabel, '2 YEARS');
    });

    test('milestoneLabel is null for a non-milestone streak', () {
      expect(StreakShareData(currentStreak: 10).milestoneLabel, isNull);
      expect(StreakShareData(currentStreak: 8).milestoneLabel, isNull);
      expect(StreakShareData(currentStreak: 1).milestoneLabel, isNull);
      expect(StreakShareData(currentStreak: 366).milestoneLabel, isNull);
    });

    test('equality is value-based', () {
      expect(
        StreakShareData(currentStreak: 7),
        StreakShareData(currentStreak: 7),
      );
      expect(
        StreakShareData(currentStreak: 7).hashCode,
        StreakShareData(currentStreak: 7).hashCode,
      );
    });
  });
}
