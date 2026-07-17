import 'package:cowbullgame/core/time/local_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDate', () {
    test('rejects an invalid month', () {
      expect(
        () => LocalDate(year: 2026, month: 13, day: 1),
        throwsArgumentError,
      );
      expect(
        () => LocalDate(year: 2026, month: 0, day: 1),
        throwsArgumentError,
      );
    });

    test('rejects an invalid day for the given month', () {
      expect(
        () => LocalDate(year: 2026, month: 4, day: 31),
        throwsArgumentError,
      );
    });

    test('rejects Feb 29 in a non-leap year', () {
      expect(
        () => LocalDate(year: 2027, month: 2, day: 29),
        throwsArgumentError,
      );
    });

    test('accepts Feb 29 in a leap year', () {
      expect(() => LocalDate(year: 2028, month: 2, day: 29), returnsNormally);
    });

    test('fromDateTime reads off the calendar fields', () {
      final date = LocalDate.fromDateTime(DateTime(2026, 7, 18, 23, 59));
      expect(date, LocalDate(year: 2026, month: 7, day: 18));
    });

    group('nextDay', () {
      test('increments within a month', () {
        final date = LocalDate(year: 2026, month: 7, day: 18);
        expect(date.nextDay, LocalDate(year: 2026, month: 7, day: 19));
      });

      test('rolls over a month boundary', () {
        final date = LocalDate(year: 2026, month: 7, day: 31);
        expect(date.nextDay, LocalDate(year: 2026, month: 8, day: 1));
      });

      test('rolls over a year boundary', () {
        final date = LocalDate(year: 2026, month: 12, day: 31);
        expect(date.nextDay, LocalDate(year: 2027, month: 1, day: 1));
      });

      test('rolls into a leap day', () {
        final date = LocalDate(year: 2028, month: 2, day: 28);
        expect(date.nextDay, LocalDate(year: 2028, month: 2, day: 29));
      });

      test('rolls out of a leap day into March', () {
        final date = LocalDate(year: 2028, month: 2, day: 29);
        expect(date.nextDay, LocalDate(year: 2028, month: 3, day: 1));
      });

      test('rolls Feb 28 to Mar 1 in a non-leap year', () {
        final date = LocalDate(year: 2027, month: 2, day: 28);
        expect(date.nextDay, LocalDate(year: 2027, month: 3, day: 1));
      });
    });

    group('epochDay', () {
      test('is 0 for the Unix epoch', () {
        expect(LocalDate(year: 1970, month: 1, day: 1).epochDay, 0);
      });

      test('increases by exactly 1 per calendar day, including a leap day', () {
        final feb28 = LocalDate(year: 2028, month: 2, day: 28);
        final feb29 = LocalDate(year: 2028, month: 2, day: 29);
        final mar1 = LocalDate(year: 2028, month: 3, day: 1);
        expect(feb29.epochDay - feb28.epochDay, 1);
        expect(mar1.epochDay - feb29.epochDay, 1);
      });

      test('is negative before the epoch', () {
        expect(LocalDate(year: 1969, month: 12, day: 31).epochDay, -1);
      });
    });

    group('parsing', () {
      test('round-trips through toIso8601String/tryParse', () {
        final date = LocalDate(year: 2026, month: 7, day: 18);
        expect(LocalDate.tryParse(date.toIso8601String()), date);
      });

      test('pads single-digit month/day', () {
        final date = LocalDate(year: 2026, month: 1, day: 5);
        expect(date.toIso8601String(), '2026-01-05');
      });

      test('rejects malformed input', () {
        expect(LocalDate.tryParse('not-a-date'), isNull);
        expect(LocalDate.tryParse('2026-13-01'), isNull);
        expect(LocalDate.tryParse('2026-02-30'), isNull);
        expect(LocalDate.tryParse(''), isNull);
        expect(LocalDate.tryParse('2026-7-18'), isNull);
      });
    });

    group('equality/ordering', () {
      test('equal dates compare equal and hash equal', () {
        final a = LocalDate(year: 2026, month: 7, day: 18);
        final b = LocalDate(year: 2026, month: 7, day: 18);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('compareTo orders chronologically', () {
        final earlier = LocalDate(year: 2026, month: 7, day: 18);
        final later = LocalDate(year: 2026, month: 7, day: 19);
        expect(earlier.compareTo(later), lessThan(0));
        expect(later.compareTo(earlier), greaterThan(0));
        expect(earlier.compareTo(earlier), 0);
      });
    });
  });
}
