import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/streak/models/streak_state.dart';
import 'package:cowbullgame/features/streak/models/streak_update_result.dart';
import 'package:cowbullgame/features/streak/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

LocalDate _d(int year, int month, int day) =>
    LocalDate(year: year, month: month, day: day);

void main() {
  const service = StreakService();

  group('StreakService.recordQualifyingDay', () {
    test('first-ever completion starts a 1-day streak', () {
      final result = service.recordQualifyingDay(
        previous: StreakState.empty(),
        today: _d(2026, 7, 18),
      );
      expect(result, isA<StreakStarted>());
      expect(result.state.currentStreak, 1);
      expect(result.state.longestStreak, 1);
      expect(result.state.lastQualifyingDate, _d(2026, 7, 18));
    });

    test('a second completion on the same date does not increment', () {
      final first = service.recordQualifyingDay(
        previous: StreakState.empty(),
        today: _d(2026, 7, 18),
      );
      final second = service.recordQualifyingDay(
        previous: first.state,
        today: _d(2026, 7, 18),
      );
      expect(second, isA<StreakAlreadyCounted>());
      expect(second.state, first.state);
    });

    test('completion on the very next day extends the streak', () {
      final day1 = service.recordQualifyingDay(
        previous: StreakState.empty(),
        today: _d(2026, 7, 18),
      );
      final day2 = service.recordQualifyingDay(
        previous: day1.state,
        today: _d(2026, 7, 19),
      );
      expect(day2, isA<StreakExtended>());
      expect(day2.state.currentStreak, 2);
      expect(day2.state.longestStreak, 2);
    });

    test('missing one calendar day resets the streak to 1', () {
      final day1 = service.recordQualifyingDay(
        previous: StreakState.empty(),
        today: _d(2026, 7, 18),
      );
      // 2026-07-19 is skipped entirely.
      final day3 = service.recordQualifyingDay(
        previous: day1.state,
        today: _d(2026, 7, 20),
      );
      expect(day3, isA<StreakStarted>());
      expect(day3.state.currentStreak, 1);
      // The longest streak from before the gap is preserved.
      expect(day3.state.longestStreak, 1);
    });

    test('missing several calendar days also resets the streak to 1', () {
      final day1 = service.recordQualifyingDay(
        previous: StreakState.empty(),
        today: _d(2026, 7, 18),
      );
      final later = service.recordQualifyingDay(
        previous: day1.state,
        today: _d(2026, 8, 1),
      );
      expect(later, isA<StreakStarted>());
      expect(later.state.currentStreak, 1);
    });

    test('longest streak only updates when the current streak exceeds it', () {
      var state = StreakState.empty();
      for (final date in [_d(2026, 7, 18), _d(2026, 7, 19), _d(2026, 7, 20)]) {
        state = service.recordQualifyingDay(previous: state, today: date).state;
      }
      expect(state.currentStreak, 3);
      expect(state.longestStreak, 3);

      // Gap resets current to 1; longest must not decrease.
      state = service
          .recordQualifyingDay(previous: state, today: _d(2026, 8, 1))
          .state;
      expect(state.currentStreak, 1);
      expect(state.longestStreak, 3);

      // Extending again must not exceed the prior best until it actually
      // does.
      state = service
          .recordQualifyingDay(previous: state, today: _d(2026, 8, 2))
          .state;
      expect(state.currentStreak, 2);
      expect(state.longestStreak, 3);
    });

    test('month-end transition (Jul 31 -> Aug 1) extends correctly', () {
      final day1 = service.recordQualifyingDay(
        previous: StreakState.empty(),
        today: _d(2026, 7, 31),
      );
      final day2 = service.recordQualifyingDay(
        previous: day1.state,
        today: _d(2026, 8, 1),
      );
      expect(day2, isA<StreakExtended>());
      expect(day2.state.currentStreak, 2);
    });

    test('year-end transition (Dec 31 -> Jan 1) extends correctly', () {
      final day1 = service.recordQualifyingDay(
        previous: StreakState.empty(),
        today: _d(2026, 12, 31),
      );
      final day2 = service.recordQualifyingDay(
        previous: day1.state,
        today: _d(2027, 1, 1),
      );
      expect(day2, isA<StreakExtended>());
      expect(day2.state.currentStreak, 2);
    });

    test(
      'leap-day transition (Feb 28 -> Feb 29 -> Mar 1) extends correctly',
      () {
        var state = StreakState.empty();
        state = service
            .recordQualifyingDay(previous: state, today: _d(2028, 2, 28))
            .state;
        final leapDayResult = service.recordQualifyingDay(
          previous: state,
          today: _d(2028, 2, 29),
        );
        expect(leapDayResult, isA<StreakExtended>());
        expect(leapDayResult.state.currentStreak, 2);

        final marchResult = service.recordQualifyingDay(
          previous: leapDayResult.state,
          today: _d(2028, 3, 1),
        );
        expect(marchResult, isA<StreakExtended>());
        expect(marchResult.state.currentStreak, 3);
      },
    );

    test('Feb 28 -> Mar 1 extends in a non-leap year, since Feb 29 does not '
        'exist and Mar 1 is genuinely the next calendar day', () {
      final day1 = service.recordQualifyingDay(
        previous: StreakState.empty(),
        today: _d(2027, 2, 28),
      );
      final marchResult = service.recordQualifyingDay(
        previous: day1.state,
        today: _d(2027, 3, 1),
      );
      expect(marchResult, isA<StreakExtended>());
      expect(marchResult.state.currentStreak, 2);
    });

    test('a genuine gap across a non-leap Feb/Mar boundary resets', () {
      final day1 = service.recordQualifyingDay(
        previous: StreakState.empty(),
        today: _d(2027, 2, 27),
      );
      // Feb 28 is skipped entirely, then Mar 1 is played — a real one-day
      // gap, distinct from the "Feb 28 -> Mar 1" adjacency case above.
      final marchResult = service.recordQualifyingDay(
        previous: day1.state,
        today: _d(2027, 3, 1),
      );
      expect(marchResult, isA<StreakStarted>());
      expect(marchResult.state.currentStreak, 1);
    });
  });
}
