// Regenerates assets/generated/*.txt from the raw dictionaries under
// assets/source/. See docs/word_lists.md for the full pipeline description.
//
// Usage: dart run scripts/generate_word_lists.dart
//
// This file is written as a library (no leading underscore on the pure,
// logic-bearing functions/classes) rather than a script with only a
// top-level `main`, so `test/scripts/generate_word_lists_test.dart` can
// import it and unit-test the ranking/partitioning logic directly instead
// of shelling out to the script repeatedly.

// This CLI script's job is to print a summary to the console, so `print`
// here is the intended interface, not a production logging omission.
// ignore_for_file: avoid_print

import 'dart:io';

/// Word lengths supported by this milestone. Extend this list (and nothing
/// else in this script) to support additional lengths later — every step
/// below is driven off it.
const List<int> supportedLengths = [4, 5, 6];

/// The three difficulty tiers secret words are partitioned into, and the
/// exact string used for each in generated filenames
/// (`secret_words_<difficulty>_<length>.txt`).
const List<String> difficultyNames = ['easy', 'common', 'hard'];

const String sourceDir = 'assets/source';
const String generatedDir = 'assets/generated';
const String allowedSourceFile = '$sourceDir/words_alpha.txt';
const String secretSourceFile = '$sourceDir/google-10000-english.txt';

/// Below this pool size, the generator's summary flags a difficulty pool as
/// impractically small for gameplay variety. A reporting threshold only —
/// generation still succeeds as long as every pool is non-empty; see
/// [_checkPoolSizesNonEmpty].
const int minimumPoolSize = 50;

final RegExp lowercaseLettersOnly = RegExp(r'^[a-z]+$');

void main() {
  final allowedRawLines = readSourceLines(allowedSourceFile);
  final secretRawLines = readSourceLines(secretSourceFile);

  // Allowed words: line order carries no meaning, so build each length's
  // pool alphabetically sorted and deduplicated.
  final allowedSource = buildSortedSource(allowedRawLines, supportedLengths);

  // Secret words: line order in google-10000-english.txt is a frequency
  // ranking (most common word first), which the difficulty partition below
  // depends on — so this preserves first-occurrence order instead of
  // sorting.
  final rankedSecretSource = buildRankedSource(
    secretRawLines,
    supportedLengths,
  );

  final allowedByLength = <int, List<String>>{};
  final allowedSetByLength = <int, Set<String>>{};
  for (final length in supportedLengths) {
    final words = allowedSource.wordsOfLength(length);
    allowedByLength[length] = words;
    allowedSetByLength[length] = words.toSet();
  }

  final eligibleByLength = <int, List<String>>{};
  final excludedCountByLength = <int, int>{};
  final poolsByLength = <int, DifficultyPools>{};
  for (final length in supportedLengths) {
    final ranked = rankedSecretSource.wordsOfLength(length);
    final allowedSet = allowedSetByLength[length]!;
    final eligible = eligibleSecretCandidates(ranked, allowedSet);
    eligibleByLength[length] = eligible;
    excludedCountByLength[length] = ranked.length - eligible.length;
    poolsByLength[length] = partitionByDifficulty(eligible);
  }

  _checkPoolSizesNonEmpty(poolsByLength);

  Directory(generatedDir).createSync(recursive: true);
  final outputCounts = <String, int>{};
  for (final length in supportedLengths) {
    outputCounts['allowed_words_$length.txt'] = _writeWordList(
      '$generatedDir/allowed_words_$length.txt',
      allowedByLength[length]!,
    );
    final pools = poolsByLength[length]!;
    for (final difficulty in difficultyNames) {
      final fileName = 'secret_words_${difficulty}_$length.txt';
      outputCounts[fileName] = _writeWordList(
        '$generatedDir/$fileName',
        _alphabetical(pools.forName(difficulty)),
      );
    }
  }

  _removeObsoleteGenericSecretFiles();

  _verifyGeneratedFiles(allowedSetByLength);

  _printSummary(
    allowedSource: allowedSource,
    rankedSecretSource: rankedSecretSource,
    outputCounts: outputCounts,
    eligibleByLength: eligibleByLength,
    excludedCountByLength: excludedCountByLength,
    poolsByLength: poolsByLength,
  );
}

/// One raw source line, normalized: trimmed, lowercased, and validated as
/// ASCII a-z only. [word] is the normalized word if [rawLine] was valid, or
/// `null` otherwise; [wasBlank] distinguishes a blank line (silently
/// skipped, never counted anywhere) from a non-blank line that failed
/// validation (counted as an invalid entry by callers).
class NormalizedLine {
  const NormalizedLine({this.word, required this.wasBlank});

  final String? word;
  final bool wasBlank;
}

/// Normalizes [rawLine] for word-list generation. See [NormalizedLine].
NormalizedLine normalizeLine(String rawLine) {
  final normalized = rawLine.trim().toLowerCase();
  if (normalized.isEmpty) return const NormalizedLine(wasBlank: true);
  if (!lowercaseLettersOnly.hasMatch(normalized)) {
    return const NormalizedLine(wasBlank: false);
  }
  return NormalizedLine(word: normalized, wasBlank: false);
}

/// Raw lines read from a source dictionary, alphabetically sorted and
/// deduplicated per supported length. Used for the allowed-guess source,
/// where line order carries no meaning.
class SortedSourceResult {
  // Takes a public `wordsByLength` parameter rather than
  // `this._wordsByLength`, since a private name in a public constructor
  // signature reads as an implementation leak.
  SortedSourceResult({
    required this.path,
    required this.rawLineCount,
    required this.invalidCount,
    required this.duplicateCount,
    required Map<int, List<String>> wordsByLength,
    // ignore: prefer_initializing_formals
  }) : _wordsByLength = wordsByLength;

  final String path;
  final int rawLineCount;
  final int invalidCount;
  final int duplicateCount;
  final Map<int, List<String>> _wordsByLength;

  List<String> wordsOfLength(int length) =>
      List.unmodifiable(_wordsByLength[length] ?? const <String>[]);
}

/// Normalizes, filters, deduplicates, and alphabetically sorts [rawLines]
/// per length in [lengths]. Lines whose normalized length is not in
/// [lengths] are silently dropped (not counted as invalid or duplicate),
/// matching the "unsupported length" behavior of the rest of this script.
SortedSourceResult buildSortedSource(
  List<String> rawLines,
  List<int> lengths, {
  String path = '',
}) {
  final seenByLength = <int, Set<String>>{
    for (final length in lengths) length: <String>{},
  };
  var invalidCount = 0;
  var duplicateCount = 0;

  for (final rawLine in rawLines) {
    final line = normalizeLine(rawLine);
    if (line.wasBlank) continue;
    final word = line.word;
    if (word == null) {
      invalidCount++;
      continue;
    }
    final seen = seenByLength[word.length];
    if (seen == null) continue;
    if (!seen.add(word)) duplicateCount++;
  }

  final wordsByLength = <int, List<String>>{
    for (final entry in seenByLength.entries)
      entry.key: (entry.value.toList()..sort()),
  };

  return SortedSourceResult(
    path: path,
    rawLineCount: rawLines.length,
    invalidCount: invalidCount,
    duplicateCount: duplicateCount,
    wordsByLength: wordsByLength,
  );
}

/// Raw lines read from a source dictionary, normalized, filtered, and
/// deduplicated per supported length while preserving each word's
/// first-occurrence order. Used for the secret-word frequency source, where
/// line order encodes how common a word is (most common first).
class RankedSourceResult {
  // Takes a public `wordsByLength` parameter rather than
  // `this._wordsByLength`, since a private name in a public constructor
  // signature reads as an implementation leak.
  RankedSourceResult({
    required this.path,
    required this.rawLineCount,
    required this.invalidCount,
    required this.duplicateCount,
    required Map<int, List<String>> wordsByLength,
    // ignore: prefer_initializing_formals
  }) : _wordsByLength = wordsByLength;

  final String path;
  final int rawLineCount;
  final int invalidCount;
  final int duplicateCount;
  final Map<int, List<String>> _wordsByLength;

  /// Words of [length], in descending-frequency (rank) order — the order
  /// they first appeared in the source file — deduplicated.
  List<String> wordsOfLength(int length) =>
      List.unmodifiable(_wordsByLength[length] ?? const <String>[]);
}

/// Normalizes, filters, and deduplicates [rawLines] per length in
/// [lengths], preserving first-occurrence (frequency-rank) order rather
/// than sorting. See [RankedSourceResult].
RankedSourceResult buildRankedSource(
  List<String> rawLines,
  List<int> lengths, {
  String path = '',
}) {
  final seenByLength = <int, Set<String>>{
    for (final length in lengths) length: <String>{},
  };
  final orderedByLength = <int, List<String>>{
    for (final length in lengths) length: <String>[],
  };
  var invalidCount = 0;
  var duplicateCount = 0;

  for (final rawLine in rawLines) {
    final line = normalizeLine(rawLine);
    if (line.wasBlank) continue;
    final word = line.word;
    if (word == null) {
      invalidCount++;
      continue;
    }
    final seen = seenByLength[word.length];
    if (seen == null) continue;
    if (!seen.add(word)) {
      duplicateCount++;
      continue;
    }
    orderedByLength[word.length]!.add(word);
  }

  return RankedSourceResult(
    path: path,
    rawLineCount: rawLines.length,
    invalidCount: invalidCount,
    duplicateCount: duplicateCount,
    wordsByLength: orderedByLength,
  );
}

/// Filters [rankedWords] (already in frequency-rank order) down to only
/// those present in [allowedSet], preserving rank order. Produces the
/// eligible secret-word candidate pool for one word length, before
/// partitioning by difficulty.
List<String> eligibleSecretCandidates(
  List<String> rankedWords,
  Set<String> allowedSet,
) => rankedWords.where(allowedSet.contains).toList();

/// The three difficulty-tier secret-word pools produced by
/// [partitionByDifficulty], each still in frequency-rank order (most
/// common first).
class DifficultyPools {
  const DifficultyPools({
    required this.easy,
    required this.common,
    required this.hard,
  });

  final List<String> easy;
  final List<String> common;
  final List<String> hard;

  /// Looks up a pool by its [difficultyNames] entry ('easy', 'common', or
  /// 'hard'). Throws [ArgumentError] for anything else.
  List<String> forName(String name) => switch (name) {
    'easy' => easy,
    'common' => common,
    'hard' => hard,
    _ => throw ArgumentError.value(
      name,
      'name',
      'must be one of $difficultyNames',
    ),
  };
}

/// Splits [rankedEligibleWords] — already frequency-ranked (most common
/// first) and filtered to the allowed-word set — into three difficulty
/// tiers:
///
/// - [DifficultyPools.easy]: the top quarter (`n ~/ 4` words) — the most
///   frequent, most familiar words;
/// - [DifficultyPools.hard]: the bottom quarter (`n ~/ 4` words) — the
///   least frequent words;
/// - [DifficultyPools.common]: everything in between — the middle half,
///   plus any remainder left over from integer division, so the three
///   pools are always disjoint and their concatenation, in order, is always
///   exactly [rankedEligibleWords].
///
/// Deterministic: the same input list always produces the same three
/// pools, since the split depends only on list order and length, with no
/// randomness or external state. See `docs/word_lists.md` for the exact
/// thresholds and the reasoning behind this split.
DifficultyPools partitionByDifficulty(List<String> rankedEligibleWords) {
  final n = rankedEligibleWords.length;
  final quarter = n ~/ 4;
  return DifficultyPools(
    easy: rankedEligibleWords.sublist(0, quarter),
    common: rankedEligibleWords.sublist(quarter, n - quarter),
    hard: rankedEligibleWords.sublist(n - quarter, n),
  );
}

/// Formats [words] as generated-file contents: one word per line, ending
/// in exactly one trailing newline — or an empty string for a zero-entry
/// list, per the generated-file spec in `docs/word_lists.md`. Assumes
/// [words] is already sorted, deduplicated, and lowercase a-z only.
String formatWordListFile(List<String> words) {
  final buffer = StringBuffer();
  for (final word in words) {
    buffer.writeln(word);
  }
  return buffer.toString();
}

/// Describes why [lines] does not satisfy the generated-word-list format
/// contract (see `docs/word_lists.md`) for [expectedLength], or `null` if
/// it does: one lowercase a-z-only entry of exactly [expectedLength] per
/// line, strictly ascending alphabetically, with no blank lines and no
/// duplicates.
String? wordListFormatViolation(List<String> lines, int expectedLength) {
  final seen = <String>{};
  String? previous;
  for (final line in lines) {
    if (line.isEmpty) return 'blank line found';
    if (!lowercaseLettersOnly.hasMatch(line)) {
      return 'malformed entry "$line"';
    }
    if (line.length != expectedLength) {
      return '"$line" has length ${line.length}, expected $expectedLength';
    }
    if (!seen.add(line)) return 'duplicate entry "$line"';
    if (previous != null && previous.compareTo(line) > 0) {
      return '"$previous" sorts after "$line"';
    }
    previous = line;
  }
  return null;
}

List<String> _alphabetical(List<String> words) =>
    List<String>.from(words)..sort();

List<String> readSourceLines(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('error: required source file not found: $path');
    exit(1);
  }
  try {
    return file.readAsLinesSync();
  } on FileSystemException catch (e) {
    stderr.writeln('error: could not read source file $path: ${e.message}');
    exit(1);
  }
}

int _writeWordList(String path, List<String> words) {
  File(path).writeAsStringSync(formatWordListFile(words));
  return words.length;
}

/// Fails generation loudly if any difficulty pool for any supported length
/// is completely empty: a zero-byte generated file would make that
/// length/difficulty combination unplayable (`EmptyWordListException` at
/// runtime). A pool merely below [minimumPoolSize] is only reported, not
/// fatal — see [_printPoolLine].
void _checkPoolSizesNonEmpty(Map<int, DifficultyPools> poolsByLength) {
  for (final length in supportedLengths) {
    final pools = poolsByLength[length]!;
    for (final difficulty in difficultyNames) {
      if (pools.forName(difficulty).isEmpty) {
        stderr.writeln(
          'error: difficulty pool "$difficulty" for length $length is '
          'empty; cannot generate a usable secret-word asset',
        );
        exit(1);
      }
    }
  }
}

/// Re-reads every generated file and checks the invariants promised in
/// docs/word_lists.md, so a bug in this script fails the run loudly instead
/// of silently shipping a malformed asset.
void _verifyGeneratedFiles(Map<int, Set<String>> allowedSetByLength) {
  for (final length in supportedLengths) {
    final allowedLines = File(
      '$generatedDir/allowed_words_$length.txt',
    ).readAsLinesSync();
    _verifyOrExit(allowedLines, length);
    final allowedSet = allowedSetByLength[length]!;

    for (final difficulty in difficultyNames) {
      final path = '$generatedDir/secret_words_${difficulty}_$length.txt';
      final secretLines = File(path).readAsLinesSync();
      _verifyOrExit(secretLines, length);

      for (final secretWord in secretLines) {
        if (!allowedSet.contains(secretWord)) {
          stderr.writeln(
            'error: verification failed: secret word "$secretWord" '
            '(length $length, difficulty $difficulty) is not in the '
            'allowed word list',
          );
          exit(1);
        }
      }
    }

    _verifyPoolsDisjoint(length);
  }
}

void _verifyPoolsDisjoint(int length) {
  final seenAcrossPools = <String>{};
  for (final difficulty in difficultyNames) {
    final path = '$generatedDir/secret_words_${difficulty}_$length.txt';
    for (final word in File(path).readAsLinesSync()) {
      if (!seenAcrossPools.add(word)) {
        stderr.writeln(
          'error: verification failed: "$word" (length $length) appears '
          'in more than one difficulty pool',
        );
        exit(1);
      }
    }
  }
}

void _verifyOrExit(List<String> lines, int expectedLength) {
  final violation = wordListFormatViolation(lines, expectedLength);
  if (violation != null) {
    stderr.writeln('error: verification failed: $violation');
    exit(1);
  }
}

/// Deletes the pre-milestone-7 generic `secret_words_<length>.txt` assets
/// if present, now that secret words are always difficulty-specific.
void _removeObsoleteGenericSecretFiles() {
  for (final length in supportedLengths) {
    final file = File('$generatedDir/secret_words_$length.txt');
    if (file.existsSync()) file.deleteSync();
  }
}

void _printSummary({
  required SortedSourceResult allowedSource,
  required RankedSourceResult rankedSecretSource,
  required Map<String, int> outputCounts,
  required Map<int, List<String>> eligibleByLength,
  required Map<int, int> excludedCountByLength,
  required Map<int, DifficultyPools> poolsByLength,
}) {
  print('Word list generation summary');
  print('=============================');
  print('Source files:');
  print(
    '  $allowedSourceFile: ${allowedSource.rawLineCount} lines read, '
    '${allowedSource.invalidCount} invalid entries removed, '
    '${allowedSource.duplicateCount} duplicates removed',
  );
  print(
    '  $secretSourceFile: ${rankedSecretSource.rawLineCount} lines read, '
    '${rankedSecretSource.invalidCount} invalid entries removed, '
    '${rankedSecretSource.duplicateCount} duplicates removed',
  );
  print('');
  print('Generated files:');
  for (final length in supportedLengths) {
    print(
      '  allowed_words_$length.txt: ${outputCounts['allowed_words_$length.txt']} words',
    );
    final eligible = eligibleByLength[length]!;
    print(
      '  secret candidates (length $length): ${eligible.length} ranked '
      'eligible words (${excludedCountByLength[length]} common words '
      'excluded: not in allowed set)',
    );
    final pools = poolsByLength[length]!;
    for (final difficulty in difficultyNames) {
      _printPoolLine(length, difficulty, pools.forName(difficulty).length);
    }
  }
  print('');
  print(
    'All generated files verified: lowercase a-z only, exact length, '
    'sorted, deduplicated, secrets subset of allowed, difficulty pools '
    'disjoint.',
  );
}

void _printPoolLine(int length, String difficulty, int count) {
  final warning = count < minimumPoolSize
      ? '  [WARNING: below minimum pool size of $minimumPoolSize]'
      : '';
  print('  secret_words_${difficulty}_$length.txt: $count words$warning');
}
