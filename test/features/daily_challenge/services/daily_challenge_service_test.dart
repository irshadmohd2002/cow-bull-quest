import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/daily_challenge/services/daily_challenge_service.dart';
import 'package:flutter_test/flutter_test.dart';

LocalDate _d(int year, int month, int day) =>
    LocalDate(year: year, month: month, day: day);

void main() {
  const service = DailyChallengeService();
  const pool = ['acid', 'acts', 'adam', 'adds', 'aged'];

  group('DailyChallengeService.secretWordFor', () {
    test('the same date always returns the same secret', () {
      final first = service.secretWordFor(_d(2026, 7, 18), pool);
      final second = service.secretWordFor(_d(2026, 7, 18), pool);
      expect(first, second);
    });

    test('is stable across separate service instances', () {
      const otherInstance = DailyChallengeService();
      expect(
        otherInstance.secretWordFor(_d(2026, 7, 18), pool),
        service.secretWordFor(_d(2026, 7, 18), pool),
      );
    });

    test('different dates map deterministically by epoch-day index', () {
      final date = _d(2026, 7, 18);
      final expectedIndex = date.epochDay % pool.length;
      expect(service.secretWordFor(date, pool), pool[expectedIndex]);
    });

    test(
      'consecutive dates select different words, for a pool larger than 1',
      () {
        // Consecutive calendar dates have epoch days exactly 1 apart, so their
        // indices mod pool.length are always different whenever pool.length
        // > 1 — this is guaranteed, not merely likely.
        final today = service.secretWordFor(_d(2026, 7, 18), pool);
        final tomorrow = service.secretWordFor(_d(2026, 7, 19), pool);
        expect(today == tomorrow, isFalse);
      },
    );

    test('the selected secret always belongs to the eligible pool', () {
      for (var i = 0; i < 30; i++) {
        final date = LocalDate(year: 2026, month: 1, day: 1 + i);
        expect(pool, contains(service.secretWordFor(date, pool)));
      }
    });

    test('the selected secret is exactly 4 letters, for a 4-letter pool', () {
      final secret = service.secretWordFor(_d(2026, 7, 18), pool);
      expect(secret.length, DailyChallengeService.wordLength);
    });

    test(
      'a month boundary selects deterministically, same as any other date',
      () {
        final julyEnd = service.secretWordFor(_d(2026, 7, 31), pool);
        final augustStart = service.secretWordFor(_d(2026, 8, 1), pool);
        expect(julyEnd, pool[_d(2026, 7, 31).epochDay % pool.length]);
        expect(augustStart, pool[_d(2026, 8, 1).epochDay % pool.length]);
      },
    );

    test(
      'a year boundary selects deterministically, same as any other date',
      () {
        final yearEnd = service.secretWordFor(_d(2026, 12, 31), pool);
        final yearStart = service.secretWordFor(_d(2027, 1, 1), pool);
        expect(yearEnd, pool[_d(2026, 12, 31).epochDay % pool.length]);
        expect(yearStart, pool[_d(2027, 1, 1).epochDay % pool.length]);
      },
    );

    test('throws ArgumentError for an empty pool', () {
      expect(
        () => service.secretWordFor(_d(2026, 7, 18), const []),
        throwsArgumentError,
      );
    });

    test('wordListVersion is an explicit, stable constant', () {
      expect(DailyChallengeService.wordListVersion, 1);
    });

    test(
      'wordLength and maxAttempts match the visible-game rules (4 letters, 10 attempts)',
      () {
        expect(DailyChallengeService.wordLength, 4);
        expect(DailyChallengeService.maxAttempts, 10);
      },
    );
  });
}
