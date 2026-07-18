import 'package:cowbullgame/features/statistics/models/completed_game.dart';
import 'package:cowbullgame/features/statistics/models/game_outcome.dart';
import 'package:cowbullgame/models/difficulty_selection.dart';
import 'package:flutter_test/flutter_test.dart';

CompletedGame _buildGame({
  String id = 'game-1',
  DateTime? completedAt,
  int wordLength = 5,
  DifficultyOption difficulty = DifficultyOption.common,
  GameOutcome outcome = GameOutcome.won,
  int attemptsUsed = 3,
  int maxAttempts = 15,
  int? hintsUsed,
}) => CompletedGame(
  id: id,
  completedAt: completedAt ?? DateTime.utc(2026, 1, 2, 3, 4, 5),
  wordLength: wordLength,
  difficulty: difficulty,
  outcome: outcome,
  attemptsUsed: attemptsUsed,
  maxAttempts: maxAttempts,
  hintsUsed: hintsUsed,
);

void main() {
  group('CompletedGame validation', () {
    test('accepts a valid record', () {
      expect(_buildGame, returnsNormally);
    });

    test('rejects an empty id', () {
      expect(() => _buildGame(id: ''), throwsArgumentError);
    });

    test('rejects an unsupported word length', () {
      expect(() => _buildGame(wordLength: 7), throwsArgumentError);
    });

    test('accepts every supported word length', () {
      for (final length in supportedCompletedGameWordLengths) {
        expect(() => _buildGame(wordLength: length), returnsNormally);
      }
    });

    test('rejects a non-positive maxAttempts', () {
      expect(
        () => _buildGame(maxAttempts: 0, attemptsUsed: 0),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive attemptsUsed', () {
      expect(() => _buildGame(attemptsUsed: 0), throwsArgumentError);
    });

    test('rejects attemptsUsed greater than maxAttempts', () {
      expect(
        () => _buildGame(attemptsUsed: 16, maxAttempts: 15),
        throwsArgumentError,
      );
    });

    test('accepts attemptsUsed equal to maxAttempts', () {
      expect(
        () => _buildGame(attemptsUsed: 15, maxAttempts: 15),
        returnsNormally,
      );
    });
  });

  group('CompletedGame JSON round-trip', () {
    test('toJson uses stable strings, never enum indexes', () {
      final game = _buildGame(
        difficulty: DifficultyOption.hard,
        outcome: GameOutcome.lost,
      );
      final json = game.toJson();

      expect(json['difficulty'], 'hard');
      expect(json['outcome'], 'lost');
    });

    test('fromJson(toJson()) reconstructs an equal record', () {
      final game = _buildGame();
      final restored = CompletedGame.fromJson(game.toJson());

      expect(restored, game);
    });

    test('toJson never includes a secret word or guesses field', () {
      final json = _buildGame().toJson();
      expect(json.containsKey('secretWord'), isFalse);
      expect(json.containsKey('guesses'), isFalse);
      expect(json.containsKey('word'), isFalse);
    });

    test('fromJson rejects a missing field', () {
      final json = _buildGame().toJson()..remove('wordLength');
      expect(() => CompletedGame.fromJson(json), throwsFormatException);
    });

    test('fromJson rejects a wrong-typed field', () {
      final json = _buildGame().toJson();
      json['wordLength'] = 'five';
      expect(() => CompletedGame.fromJson(json), throwsFormatException);
    });

    test('fromJson rejects an unrecognized difficulty string', () {
      final json = _buildGame().toJson();
      json['difficulty'] = 'medium';
      expect(() => CompletedGame.fromJson(json), throwsFormatException);
    });

    test('fromJson rejects an unrecognized outcome string', () {
      final json = _buildGame().toJson();
      json['outcome'] = 'draw';
      expect(() => CompletedGame.fromJson(json), throwsFormatException);
    });

    test('fromJson rejects an invalid completedAt timestamp', () {
      final json = _buildGame().toJson();
      json['completedAt'] = 'not-a-date';
      expect(() => CompletedGame.fromJson(json), throwsFormatException);
    });

    test('fromJson still runs constructor validation', () {
      final json = _buildGame().toJson();
      json['attemptsUsed'] = 99;
      expect(() => CompletedGame.fromJson(json), throwsArgumentError);
    });
  });

  group('Milestone 19: hintsUsed', () {
    test('defaults to null (unknown) when not supplied', () {
      expect(_buildGame().hintsUsed, isNull);
    });

    test('accepts 0 — a real, known no-hint win', () {
      expect(_buildGame(hintsUsed: 0).hintsUsed, 0);
    });

    test('rejects a negative hintsUsed', () {
      expect(() => _buildGame(hintsUsed: -1), throwsArgumentError);
    });

    test('toJson always includes the "hintsUsed" key, as an int or JSON '
        'null', () {
      expect(_buildGame(hintsUsed: 2).toJson()['hintsUsed'], 2);
      expect(_buildGame().toJson().containsKey('hintsUsed'), isTrue);
      expect(_buildGame().toJson()['hintsUsed'], isNull);
    });

    test('fromJson(toJson()) round-trips a known hintsUsed value', () {
      final game = _buildGame(hintsUsed: 1);
      expect(CompletedGame.fromJson(game.toJson()).hintsUsed, 1);
    });

    test('fromJson decodes a record with no "hintsUsed" key at all (every '
        'record written before Milestone 19) as null, never 0 — this is the '
        'exact migration rule that keeps an old win from being misclassified '
        'as hint-free', () {
      final json = _buildGame().toJson()..remove('hintsUsed');
      expect(CompletedGame.fromJson(json).hintsUsed, isNull);
    });

    test(
      'fromJson decodes an explicit JSON null the same as a missing key',
      () {
        final json = _buildGame().toJson();
        json['hintsUsed'] = null;
        expect(CompletedGame.fromJson(json).hintsUsed, isNull);
      },
    );

    test('fromJson rejects a non-int, non-null hintsUsed', () {
      final json = _buildGame().toJson();
      json['hintsUsed'] = 'two';
      expect(() => CompletedGame.fromJson(json), throwsFormatException);
    });

    test('two records differing only in hintsUsed are not equal', () {
      expect(_buildGame(hintsUsed: 0), isNot(_buildGame(hintsUsed: 1)));
      expect(_buildGame(hintsUsed: null), isNot(_buildGame(hintsUsed: 0)));
    });
  });
}
