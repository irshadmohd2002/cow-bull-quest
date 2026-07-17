import 'package:cowbullgame/core/time/local_date.dart';
import 'package:cowbullgame/features/daily_challenge/models/daily_challenge_result.dart';
import 'package:flutter_test/flutter_test.dart';

DailyChallengeResult _result({
  bool won = true,
  int attemptsUsed = 3,
  int hintsUsed = 1,
}) => DailyChallengeResult(
  date: LocalDate(year: 2026, month: 7, day: 18),
  won: won,
  attemptsUsed: attemptsUsed,
  maxAttempts: 10,
  hintsUsed: hintsUsed,
  completedAt: DateTime.utc(2026, 7, 18, 12),
  wordListVersion: 1,
  guesses: const [
    DailyChallengeGuessRecord(turnNumber: 1, bulls: 1, cows: 2),
    DailyChallengeGuessRecord(turnNumber: 2, bulls: 4, cows: 0),
  ],
);

void main() {
  group('DailyChallengeResult', () {
    test('rejects attemptsUsed exceeding maxAttempts', () {
      expect(
        () => DailyChallengeResult(
          date: LocalDate(year: 2026, month: 7, day: 18),
          won: false,
          attemptsUsed: 11,
          maxAttempts: 10,
          hintsUsed: 0,
          completedAt: DateTime.utc(2026, 7, 18),
          wordListVersion: 1,
          guesses: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive attemptsUsed', () {
      expect(
        () => DailyChallengeResult(
          date: LocalDate(year: 2026, month: 7, day: 18),
          won: false,
          attemptsUsed: 0,
          maxAttempts: 10,
          hintsUsed: 0,
          completedAt: DateTime.utc(2026, 7, 18),
          wordListVersion: 1,
          guesses: const [],
        ),
        throwsArgumentError,
      );
    });

    test('round-trips a won result through toJson/fromJson', () {
      final result = _result();
      expect(DailyChallengeResult.fromJson(result.toJson()), result);
    });

    test('round-trips a lost result through toJson/fromJson', () {
      final result = _result(won: false, attemptsUsed: 10, hintsUsed: 0);
      expect(DailyChallengeResult.fromJson(result.toJson()), result);
    });

    test('stores attempts and hints accurately', () {
      final result = _result(attemptsUsed: 5, hintsUsed: 1);
      expect(result.attemptsUsed, 5);
      expect(result.hintsUsed, 1);
    });

    test('fromJson rejects an unsupported version', () {
      final json = _result().toJson()..['version'] = 999;
      expect(() => DailyChallengeResult.fromJson(json), throwsFormatException);
    });

    test('fromJson rejects a malformed date', () {
      final json = _result().toJson()..['date'] = 'not-a-date';
      expect(() => DailyChallengeResult.fromJson(json), throwsFormatException);
    });

    test('never serializes a secret word or guessed words', () {
      final json = _result().toJson();
      expect(jsonEncodeContains(json, 'secretword'), isFalse);
      expect(jsonEncodeContains(json, 'guessword'), isFalse);
      // The only recognized keys are the ones this model documents; a
      // guessed word would show up as an extra, unexpected string value
      // among the guess records, which only ever carry ints.
      final guesses = json['guesses'] as List;
      for (final guess in guesses.cast<Map<String, Object?>>()) {
        expect(guess.keys, {'turnNumber', 'bulls', 'cows'});
      }
    });
  });
}

/// Deep-searches [json] for any key literally named "word" or "secretWord" —
/// a cheap structural guard against accidentally serializing gameplay
/// content this model must never carry.
bool jsonEncodeContains(Map<String, Object?> json, String forbiddenKeyPart) {
  for (final entry in json.entries) {
    if (entry.key.toLowerCase().contains(forbiddenKeyPart)) return true;
    final value = entry.value;
    if (value is Map<String, Object?> &&
        jsonEncodeContains(value, forbiddenKeyPart)) {
      return true;
    }
    if (value is List) {
      for (final item in value) {
        if (item is Map<String, Object?> &&
            jsonEncodeContains(item, forbiddenKeyPart)) {
          return true;
        }
      }
    }
  }
  return false;
}
