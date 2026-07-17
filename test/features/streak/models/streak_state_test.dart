import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/streak/models/streak_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakState', () {
    test('empty starts at zero on both counters with no last date', () {
      final state = StreakState.empty();
      expect(state.currentStreak, 0);
      expect(state.longestStreak, 0);
      expect(state.lastQualifyingDate, isNull);
    });

    test('rejects a negative currentStreak', () {
      expect(
        () => StreakState(currentStreak: -1, longestStreak: 0),
        throwsArgumentError,
      );
    });

    test('rejects a negative longestStreak', () {
      expect(
        () => StreakState(currentStreak: 0, longestStreak: -1),
        throwsArgumentError,
      );
    });

    test('rejects currentStreak exceeding longestStreak', () {
      expect(
        () => StreakState(currentStreak: 5, longestStreak: 3),
        throwsArgumentError,
      );
    });

    test('round-trips through toJson/fromJson', () {
      final state = StreakState(
        currentStreak: 4,
        longestStreak: 8,
        lastQualifyingDate: LocalDate(year: 2026, month: 7, day: 18),
      );
      expect(StreakState.fromJson(state.toJson()), state);
    });

    test('round-trips a null lastQualifyingDate', () {
      final state = StreakState.empty();
      expect(StreakState.fromJson(state.toJson()), state);
    });

    test('fromJson rejects an unsupported version', () {
      expect(
        () => StreakState.fromJson({
          'version': 999,
          'currentStreak': 0,
          'longestStreak': 0,
          'lastQualifyingDate': null,
        }),
        throwsFormatException,
      );
    });

    test('fromJson rejects a non-int currentStreak', () {
      expect(
        () => StreakState.fromJson({
          'version': 1,
          'currentStreak': 'oops',
          'longestStreak': 0,
          'lastQualifyingDate': null,
        }),
        throwsFormatException,
      );
    });

    test('fromJson rejects an unparseable lastQualifyingDate', () {
      expect(
        () => StreakState.fromJson({
          'version': 1,
          'currentStreak': 1,
          'longestStreak': 1,
          'lastQualifyingDate': 'not-a-date',
        }),
        throwsFormatException,
      );
    });

    test(
      'fromJson rejects an invalid negative streak via constructor validation',
      () {
        expect(
          () => StreakState.fromJson({
            'version': 1,
            'currentStreak': -3,
            'longestStreak': 0,
            'lastQualifyingDate': null,
          }),
          throwsArgumentError,
        );
      },
    );

    test('equal states compare equal and hash equal', () {
      final a = StreakState(currentStreak: 2, longestStreak: 5);
      final b = StreakState(currentStreak: 2, longestStreak: 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
