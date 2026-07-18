import 'dart:convert';
import 'dart:math' as math;

import '../../../core/persistence/preferences_store.dart';
import '../../../core/persistence/storage_keys.dart';
import '../../../models/difficulty_selection.dart';
import '../models/completed_game.dart';
import '../models/difficulty_storage.dart';
import '../models/game_outcome.dart';
import '../models/game_outcome_breakdown.dart';
import '../models/statistics_snapshot.dart';
import 'statistics_repository.dart';

/// The document version this implementation writes. Version 3 adds
/// [_StatisticsDocument.fewestAttemptsOnWins], [_StatisticsDocument.totalHintsUsed],
/// and [_StatisticsDocument.hintFreeWins] (Milestone 19); versions 1 (no
/// [_StatisticsDocument.recordedGameIds]) and 2 (no hint/fewest-attempts
/// fields) are both still readable — see [_documentFromDoc] — but every
/// write upgrades to this version.
const int _currentDocumentVersion = 3;

/// Every document version this implementation can read. Anything else
/// (missing, `0`, or a future version this code predates) is rejected
/// explicitly via [StatisticsRepositoryException] rather than guessed at.
const Set<int> _supportedReadVersions = {1, 2, 3};

/// The fully-durable persisted statistics state: a superset of
/// [StatisticsSnapshot] that additionally tracks [recordedGameIds] — every
/// game ID ever successfully recorded, independent of [recentGames]'s
/// bounded, display-only 20-entry window. Kept private to this file rather
/// than added to [StatisticsSnapshot] itself, since presentation code has
/// no genuine need to see the full ID set — only this repository's own
/// duplicate-detection logic does.
class _StatisticsDocument {
  _StatisticsDocument({
    required this.wins,
    required this.losses,
    required this.currentWinStreak,
    required this.bestWinStreak,
    required this.totalAttemptsOnWins,
    required this.fewestAttemptsOnWins,
    required this.totalHintsUsed,
    required this.hintFreeWins,
    required this.byWordLength,
    required this.byDifficulty,
    required this.recentGames,
    required this.recordedGameIds,
  });

  factory _StatisticsDocument.empty() => _StatisticsDocument(
    wins: 0,
    losses: 0,
    currentWinStreak: 0,
    bestWinStreak: 0,
    totalAttemptsOnWins: 0,
    fewestAttemptsOnWins: null,
    totalHintsUsed: 0,
    hintFreeWins: 0,
    byWordLength: const {},
    byDifficulty: const {},
    recentGames: const [],
    recordedGameIds: const {},
  );

  final int wins;
  final int losses;
  final int currentWinStreak;
  final int bestWinStreak;
  final int totalAttemptsOnWins;
  final int? fewestAttemptsOnWins;
  final int totalHintsUsed;
  final int hintFreeWins;
  final Map<int, GameOutcomeBreakdown> byWordLength;
  final Map<DifficultyOption, GameOutcomeBreakdown> byDifficulty;
  final List<CompletedGame> recentGames;

  /// Every game ID ever successfully recorded. Used for duplicate
  /// detection instead of [recentGames] alone, so a game that has aged out
  /// of the bounded recent list still cannot be recorded a second time.
  final Set<String> recordedGameIds;

  /// The presentation-facing projection of this document.
  StatisticsSnapshot toSnapshot() => StatisticsSnapshot(
    wins: wins,
    losses: losses,
    currentWinStreak: currentWinStreak,
    bestWinStreak: bestWinStreak,
    totalAttemptsOnWins: totalAttemptsOnWins,
    fewestAttemptsOnWins: fewestAttemptsOnWins,
    totalHintsUsed: totalHintsUsed,
    hintFreeWins: hintFreeWins,
    byWordLength: byWordLength,
    byDifficulty: byDifficulty,
    recentGames: recentGames,
  );
}

/// [StatisticsRepository] backed by a [PreferencesStore], storing one
/// versioned JSON document under [StorageKeys.statistics].
///
/// Every public operation is funneled through [_enqueue] so
/// `loadSnapshot`/`recordCompletedGame`/`clearStatistics` calls on this
/// instance always run one at a time, in the order they were invoked —
/// otherwise two concurrent `recordCompletedGame` calls could both read the
/// same pre-write document and the later write would silently clobber the
/// earlier one's update, and a `recordCompletedGame` racing a
/// `clearStatistics` could resurrect data the clear was meant to remove.
/// Nothing here is a global mutable singleton: this class holds no static
/// state (the serialization queue is per-instance), so `AppBootstrap` can
/// construct exactly one instance per [PreferencesStore] and hand it to
/// whichever `StatisticsController` owns it.
class LocalStatisticsRepository implements StatisticsRepository {
  LocalStatisticsRepository({required PreferencesStore store})
    : _store = store; // ignore: prefer_initializing_formals

  final PreferencesStore _store;

  /// The tail of this instance's operation queue. Every public call chains
  /// its work onto this future and then replaces it with a
  /// failure-swallowing continuation of its own result, so: (a) operations
  /// always run in invocation order, never interleaved, and (b) one
  /// operation throwing can never permanently wedge every later queued
  /// call — only the caller of the failing operation sees its error.
  Future<void> _tail = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<StatisticsSnapshot> loadSnapshot() =>
      _enqueue(() async => (await _loadDocument()).toSnapshot());

  @override
  Future<StatisticsSnapshot> recordCompletedGame(CompletedGame game) =>
      _enqueue(() async {
        final current = await _loadDocument();
        if (current.recordedGameIds.contains(game.id)) {
          return current.toSnapshot();
        }
        final updated = _applyCompletedGame(current, game);
        await _store.setString(
          StorageKeys.statistics,
          jsonEncode(_encode(updated)),
        );
        return updated.toSnapshot();
      });

  @override
  Future<StatisticsSnapshot> clearStatistics() => _enqueue(() async {
    await _store.remove(StorageKeys.statistics);
    return StatisticsSnapshot.empty();
  });

  /// Reads and decodes the current document directly, bypassing the public,
  /// enqueued [loadSnapshot]. [recordCompletedGame] must read this way —
  /// calling the enqueued [loadSnapshot] from inside an already-enqueued
  /// operation would deadlock, since that operation *is* the current tail.
  Future<_StatisticsDocument> _loadDocument() async {
    final raw = await _store.getString(StorageKeys.statistics);
    return _decode(raw);
  }

  _StatisticsDocument _decode(String? raw) {
    if (raw == null) return _StatisticsDocument.empty();

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw StatisticsRepositoryException('malformed statistics data: $error');
    }
    if (decoded is! Map) {
      throw const StatisticsRepositoryException(
        'malformed statistics data: expected a JSON object',
      );
    }
    final doc = decoded.cast<String, Object?>();

    final version = doc['version'];
    if (!_supportedReadVersions.contains(version)) {
      throw StatisticsRepositoryException(
        'unsupported statistics document version: $version',
      );
    }

    try {
      return _documentFromDoc(doc, version: version as int);
    } catch (error) {
      throw StatisticsRepositoryException('malformed statistics data: $error');
    }
  }

  _StatisticsDocument _documentFromDoc(
    Map<String, Object?> doc, {
    required int version,
  }) {
    final byWordLength = _decodeWordLengthBreakdown(doc['byWordLength']);
    final byDifficulty = _decodeDifficultyBreakdown(doc['byDifficulty']);
    final recentGames = _decodeRecentGames(doc['recentGames']);
    final wins = _requireInt(doc, 'wins');
    final losses = _requireInt(doc, 'losses');
    final currentWinStreak = _requireInt(doc, 'currentWinStreak');
    final bestWinStreak = _requireInt(doc, 'bestWinStreak');
    final totalAttemptsOnWins = _requireInt(doc, 'totalAttemptsOnWins');

    _checkNoDuplicateIds(recentGames);
    _checkBreakdownSumsMatchAggregates(
      byWordLength: byWordLength,
      byDifficulty: byDifficulty,
      wins: wins,
      losses: losses,
    );

    final Set<String> recordedGameIds;
    if (version == 1) {
      // Migration: v1 documents have no recordedGameIds field. Synthesize
      // it from whatever ids remain in recentGames — anything already
      // truncated out of v1's recentGames is unrecoverable, but that is no
      // worse than v1's own recentGames-only duplicate protection ever
      // provided. The next successful record/clear persists this as the
      // current version.
      recordedGameIds = {for (final game in recentGames) game.id};
    } else {
      recordedGameIds = _decodeRecordedGameIds(doc['recordedGameIds']);
      for (final game in recentGames) {
        if (!recordedGameIds.contains(game.id)) {
          throw FormatException(
            '"recentGames" contains id "${game.id}" missing from '
            '"recordedGameIds"',
          );
        }
      }
    }

    final int? fewestAttemptsOnWins;
    final int totalHintsUsed;
    final int hintFreeWins;
    if (version < 3) {
      // Migration (Milestone 19): versions 1 and 2 predate hint tracking
      // and the fewest-attempts-on-wins record entirely, so there is no
      // stored value for any of the three to read.
      //
      // totalHintsUsed/hintFreeWins: deliberately seeded at 0, never
      // "recovered" from recentGames — every game already recorded under
      // these older versions has unknown hint usage (CompletedGame.hintsUsed
      // decodes as null for all of them, per its own migration rule), and
      // "unknown" must never be counted as "used zero hints". Both counters
      // become exact for every game recorded from this point on.
      //
      // fewestAttemptsOnWins: unlike hint usage, attemptsUsed was already
      // tracked by every prior version, so this is recoverable — but only
      // as a best-effort lower bound over whichever won games are still
      // present in the bounded recentGames window; a win that already aged
      // out of that window before this migration ran is unrecoverable. See
      // StatisticsSnapshot.fewestAttemptsOnWins's own doc.
      final recentWinAttempts = [
        for (final game in recentGames)
          if (game.outcome == GameOutcome.won) game.attemptsUsed,
      ];
      fewestAttemptsOnWins = recentWinAttempts.isEmpty
          ? null
          : recentWinAttempts.reduce(math.min);
      totalHintsUsed = 0;
      hintFreeWins = 0;
    } else {
      fewestAttemptsOnWins = _readOptionalInt(doc, 'fewestAttemptsOnWins');
      totalHintsUsed = _requireInt(doc, 'totalHintsUsed');
      hintFreeWins = _requireInt(doc, 'hintFreeWins');
    }

    return _StatisticsDocument(
      wins: wins,
      losses: losses,
      currentWinStreak: currentWinStreak,
      bestWinStreak: bestWinStreak,
      totalAttemptsOnWins: totalAttemptsOnWins,
      fewestAttemptsOnWins: fewestAttemptsOnWins,
      totalHintsUsed: totalHintsUsed,
      hintFreeWins: hintFreeWins,
      byWordLength: byWordLength,
      byDifficulty: byDifficulty,
      recentGames: recentGames,
      recordedGameIds: recordedGameIds,
    );
  }

  Map<int, GameOutcomeBreakdown> _decodeWordLengthBreakdown(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('"byWordLength" must be an object');
    }
    final result = <int, GameOutcomeBreakdown>{};
    for (final entry in raw.entries) {
      final wordLength = int.parse(entry.key as String);
      // Missing-entry policy: a supported length with no persisted entry
      // simply has no breakdown key at all (treated as zero games/wins by
      // callers, e.g. via `?? GameOutcomeBreakdown.empty`) — only a key
      // for a length outside the supported set is rejected here.
      if (!supportedCompletedGameWordLengths.contains(wordLength)) {
        throw FormatException(
          '"byWordLength" has an unsupported word length: $wordLength',
        );
      }
      result[wordLength] = GameOutcomeBreakdown.fromJson(
        (entry.value as Map).cast<String, Object?>(),
      );
    }
    return result;
  }

  Map<DifficultyOption, GameOutcomeBreakdown> _decodeDifficultyBreakdown(
    Object? raw,
  ) {
    if (raw is! Map) {
      throw const FormatException('"byDifficulty" must be an object');
    }
    return {
      for (final entry in raw.entries)
        // difficultyOptionFromStorage already rejects any key outside the
        // supported DifficultyOption values, so no separate check is
        // needed here — the same missing-entry policy as word length
        // applies: an absent key means zero games/wins for that category.
        difficultyOptionFromStorage(
          entry.key as String,
        ): GameOutcomeBreakdown.fromJson(
          (entry.value as Map).cast<String, Object?>(),
        ),
    };
  }

  List<CompletedGame> _decodeRecentGames(Object? raw) {
    if (raw is! List) {
      throw const FormatException('"recentGames" must be an array');
    }
    return [
      for (final entry in raw)
        CompletedGame.fromJson((entry as Map).cast<String, Object?>()),
    ];
  }

  Set<String> _decodeRecordedGameIds(Object? raw) {
    if (raw is! List) {
      throw const FormatException('"recordedGameIds" must be an array');
    }
    final ids = <String>[
      for (final entry in raw)
        if (entry is String)
          entry
        else
          throw const FormatException(
            '"recordedGameIds" entries must be strings',
          ),
    ];
    final unique = ids.toSet();
    // Strict policy: recordedGameIds persists a set as a JSON array, which
    // must never contain a repeated id. A duplicate here is treated as
    // malformed data rather than silently deduplicated, since silently
    // normalizing it could mask a real bug in whatever produced this
    // document.
    if (unique.length != ids.length) {
      throw const FormatException('"recordedGameIds" contains a duplicate id');
    }
    return unique;
  }

  void _checkNoDuplicateIds(List<CompletedGame> recentGames) {
    final ids = [for (final game in recentGames) game.id];
    if (ids.toSet().length != ids.length) {
      throw const FormatException('"recentGames" contains a duplicate id');
    }
  }

  /// Cross-validates that the by-word-length and by-difficulty breakdowns
  /// actually sum to the top-level aggregates — every game this repository
  /// itself ever records updates exactly one word-length entry and exactly
  /// one difficulty entry alongside the aggregate counters, so a genuine
  /// document always satisfies this; a mismatch means the data was
  /// corrupted or hand-edited. Deliberately does not check `recentGames`
  /// length against the aggregate total: that list is intentionally
  /// truncated to [maxRecentGames] and is expected to fall behind it.
  void _checkBreakdownSumsMatchAggregates({
    required Map<int, GameOutcomeBreakdown> byWordLength,
    required Map<DifficultyOption, GameOutcomeBreakdown> byDifficulty,
    required int wins,
    required int losses,
  }) {
    final totalGames = wins + losses;

    var wordLengthTotalGames = 0;
    var wordLengthWins = 0;
    for (final breakdown in byWordLength.values) {
      wordLengthTotalGames += breakdown.totalGames;
      wordLengthWins += breakdown.wins;
    }
    if (wordLengthTotalGames != totalGames) {
      throw FormatException(
        '"byWordLength" totalGames sum ($wordLengthTotalGames) does not '
        'match aggregate totalGames ($totalGames)',
      );
    }
    if (wordLengthWins != wins) {
      throw FormatException(
        '"byWordLength" wins sum ($wordLengthWins) does not match '
        'aggregate wins ($wins)',
      );
    }

    var difficultyTotalGames = 0;
    var difficultyWins = 0;
    for (final breakdown in byDifficulty.values) {
      difficultyTotalGames += breakdown.totalGames;
      difficultyWins += breakdown.wins;
    }
    if (difficultyTotalGames != totalGames) {
      throw FormatException(
        '"byDifficulty" totalGames sum ($difficultyTotalGames) does not '
        'match aggregate totalGames ($totalGames)',
      );
    }
    if (difficultyWins != wins) {
      throw FormatException(
        '"byDifficulty" wins sum ($difficultyWins) does not match '
        'aggregate wins ($wins)',
      );
    }
  }

  int _requireInt(Map<String, Object?> doc, String key) {
    final value = doc[key];
    if (value is! int) {
      throw FormatException('"$key" must be an int');
    }
    return value;
  }

  /// Reads [key] as an `int?` — `null` is a valid, meaningful value (e.g.
  /// "no win recorded yet"), unlike [_requireInt]'s fields, so this accepts
  /// either an int or an explicit JSON `null`/absent key.
  int? _readOptionalInt(Map<String, Object?> doc, String key) {
    final value = doc[key];
    if (value == null) return null;
    if (value is! int) {
      throw FormatException('"$key" must be an int or null');
    }
    return value;
  }

  Map<String, Object?> _encode(_StatisticsDocument document) => {
    'version': _currentDocumentVersion,
    'wins': document.wins,
    'losses': document.losses,
    'currentWinStreak': document.currentWinStreak,
    'bestWinStreak': document.bestWinStreak,
    'totalAttemptsOnWins': document.totalAttemptsOnWins,
    'fewestAttemptsOnWins': document.fewestAttemptsOnWins,
    'totalHintsUsed': document.totalHintsUsed,
    'hintFreeWins': document.hintFreeWins,
    'byWordLength': {
      for (final entry in document.byWordLength.entries)
        '${entry.key}': entry.value.toJson(),
    },
    'byDifficulty': {
      for (final entry in document.byDifficulty.entries)
        entry.key.storageValue: entry.value.toJson(),
    },
    'recentGames': [for (final game in document.recentGames) game.toJson()],
    'recordedGameIds': document.recordedGameIds.toList(),
  };
}

/// Folds [game] into [previous], updating every aggregate — win/loss
/// counts, both streaks, the win-attempts total, the fewest-attempts
/// record, the hint totals, the by-word-length and by-difficulty
/// breakdowns, and [_StatisticsDocument.recordedGameIds] — independently of
/// [_StatisticsDocument.recentGames], and only then prepends [game] to the
/// (possibly truncated) recent-games list. This ordering is what keeps the
/// aggregates (and the durable ID set) valid even once older games age out
/// of the bounded recent list.
_StatisticsDocument _applyCompletedGame(
  _StatisticsDocument previous,
  CompletedGame game,
) {
  final won = game.outcome == GameOutcome.won;

  final currentWinStreak = won ? previous.currentWinStreak + 1 : 0;
  final bestWinStreak = math.max(previous.bestWinStreak, currentWinStreak);

  final previousFewest = previous.fewestAttemptsOnWins;
  final fewestAttemptsOnWins = won
      ? (previousFewest == null
            ? game.attemptsUsed
            : math.min(previousFewest, game.attemptsUsed))
      : previousFewest;

  // See CompletedGame.hintsUsed's doc: null (unknown) contributes nothing to
  // the running total and can never count as a hint-free win.
  final hintsUsed = game.hintsUsed;
  final totalHintsUsed = previous.totalHintsUsed + (hintsUsed ?? 0);
  final hintFreeWins = previous.hintFreeWins + (won && hintsUsed == 0 ? 1 : 0);

  final byWordLength = Map<int, GameOutcomeBreakdown>.from(
    previous.byWordLength,
  );
  final previousLengthBreakdown =
      byWordLength[game.wordLength] ?? GameOutcomeBreakdown.empty;
  byWordLength[game.wordLength] = GameOutcomeBreakdown(
    totalGames: previousLengthBreakdown.totalGames + 1,
    wins: previousLengthBreakdown.wins + (won ? 1 : 0),
  );

  final byDifficulty = Map<DifficultyOption, GameOutcomeBreakdown>.from(
    previous.byDifficulty,
  );
  final previousDifficultyBreakdown =
      byDifficulty[game.difficulty] ?? GameOutcomeBreakdown.empty;
  byDifficulty[game.difficulty] = GameOutcomeBreakdown(
    totalGames: previousDifficultyBreakdown.totalGames + 1,
    wins: previousDifficultyBreakdown.wins + (won ? 1 : 0),
  );

  final recentGames = [game, ...previous.recentGames];
  final truncatedRecentGames = recentGames.length > maxRecentGames
      ? recentGames.sublist(0, maxRecentGames)
      : recentGames;

  final recordedGameIds = {...previous.recordedGameIds, game.id};

  return _StatisticsDocument(
    wins: previous.wins + (won ? 1 : 0),
    losses: previous.losses + (won ? 0 : 1),
    currentWinStreak: currentWinStreak,
    bestWinStreak: bestWinStreak,
    totalAttemptsOnWins:
        previous.totalAttemptsOnWins + (won ? game.attemptsUsed : 0),
    fewestAttemptsOnWins: fewestAttemptsOnWins,
    totalHintsUsed: totalHintsUsed,
    hintFreeWins: hintFreeWins,
    byWordLength: byWordLength,
    byDifficulty: byDifficulty,
    recentGames: truncatedRecentGames,
    recordedGameIds: recordedGameIds,
  );
}
