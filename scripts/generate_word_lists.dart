// Regenerates assets/generated/*.txt from the raw dictionaries under
// assets/source/. See docs/word_lists.md for the full pipeline description.
//
// Usage: dart run scripts/generate_word_lists.dart

// This CLI script's job is to print a summary to the console, so `print`
// here is the intended interface, not a production logging omission.
// ignore_for_file: avoid_print

import 'dart:io';

/// Word lengths supported by this milestone. Extend this list (and nothing
/// else in this script) to support additional lengths later — every step
/// below is driven off it.
const List<int> supportedLengths = [4, 5, 6];

const String sourceDir = 'assets/source';
const String generatedDir = 'assets/generated';
const String allowedSourceFile = '$sourceDir/words_alpha.txt';
const String secretSourceFile = '$sourceDir/google-10000-english.txt';

final RegExp _lowercaseLettersOnly = RegExp(r'^[a-z]+$');

void main() {
  final allowedSource = _readSource(allowedSourceFile);
  final secretSource = _readSource(secretSourceFile);

  final allowedByLength = <int, List<String>>{};
  final allowedSetByLength = <int, Set<String>>{};
  for (final length in supportedLengths) {
    final words = allowedSource.wordsOfLength(length);
    allowedByLength[length] = words;
    allowedSetByLength[length] = words.toSet();
  }

  final secretByLength = <int, List<String>>{};
  final excludedCountByLength = <int, int>{};
  for (final length in supportedLengths) {
    final candidates = secretSource.wordsOfLength(length);
    final allowedSet = allowedSetByLength[length]!;
    final subset = candidates.where(allowedSet.contains).toList();
    secretByLength[length] = subset;
    excludedCountByLength[length] = candidates.length - subset.length;
  }

  Directory(generatedDir).createSync(recursive: true);
  final outputCounts = <String, int>{};
  for (final length in supportedLengths) {
    outputCounts['allowed_words_$length.txt'] = _writeWordList(
      '$generatedDir/allowed_words_$length.txt',
      allowedByLength[length]!,
    );
    outputCounts['secret_words_$length.txt'] = _writeWordList(
      '$generatedDir/secret_words_$length.txt',
      secretByLength[length]!,
    );
  }

  _verifyGeneratedFiles(allowedSetByLength);

  _printSummary(
    allowedSource: allowedSource,
    secretSource: secretSource,
    outputCounts: outputCounts,
    excludedCountByLength: excludedCountByLength,
  );
}

/// Raw lines read from a source dictionary, plus the per-length results of
/// normalizing/validating/filtering/deduplicating them.
class _SourceResult {
  _SourceResult({
    required this.path,
    required this.rawLineCount,
    required this.invalidCount,
    required this.duplicateCount,
    required this._wordsByLength,
  });

  final String path;
  final int rawLineCount;
  final int invalidCount;
  final int duplicateCount;
  final Map<int, List<String>> _wordsByLength;

  List<String> wordsOfLength(int length) =>
      List.unmodifiable(_wordsByLength[length] ?? const <String>[]);
}

_SourceResult _readSource(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('error: required source file not found: $path');
    exit(1);
  }

  final List<String> rawLines;
  try {
    rawLines = file.readAsLinesSync();
  } on FileSystemException catch (e) {
    stderr.writeln('error: could not read source file $path: ${e.message}');
    exit(1);
  }

  final seenByLength = <int, Set<String>>{
    for (final length in supportedLengths) length: <String>{},
  };
  var invalidCount = 0;
  var duplicateCount = 0;

  for (final rawLine in rawLines) {
    final normalized = rawLine.trim().toLowerCase();
    if (normalized.isEmpty) continue;
    if (!_lowercaseLettersOnly.hasMatch(normalized)) {
      invalidCount++;
      continue;
    }
    final seen = seenByLength[normalized.length];
    if (seen == null) continue; // Unsupported length: silently filtered.
    if (!seen.add(normalized)) {
      duplicateCount++;
    }
  }

  final wordsByLength = <int, List<String>>{
    for (final entry in seenByLength.entries)
      entry.key: entry.value.toList()..sort(),
  };

  return _SourceResult(
    path: path,
    rawLineCount: rawLines.length,
    invalidCount: invalidCount,
    duplicateCount: duplicateCount,
    wordsByLength: wordsByLength,
  );
}

int _writeWordList(String path, List<String> words) {
  final buffer = StringBuffer();
  for (final word in words) {
    buffer.writeln(word);
  }
  File(path).writeAsStringSync(buffer.toString());
  return words.length;
}

/// Re-reads every generated file and checks the invariants promised in
/// docs/word_lists.md, so a bug in this script fails the run loudly instead
/// of silently shipping a malformed asset.
void _verifyGeneratedFiles(Map<int, Set<String>> allowedSetByLength) {
  for (final length in supportedLengths) {
    final allowedLines = File(
      '$generatedDir/allowed_words_$length.txt',
    ).readAsLinesSync();
    _verifyWordList(allowedLines, length);

    final secretLines = File(
      '$generatedDir/secret_words_$length.txt',
    ).readAsLinesSync();
    _verifyWordList(secretLines, length);

    final allowedSet = allowedSetByLength[length]!;
    for (final secretWord in secretLines) {
      if (!allowedSet.contains(secretWord)) {
        stderr.writeln(
          'error: verification failed: secret word "$secretWord" '
          '(length $length) is not in the allowed word list',
        );
        exit(1);
      }
    }
  }
}

void _verifyWordList(List<String> lines, int expectedLength) {
  final seen = <String>{};
  String? previous;
  for (final line in lines) {
    if (line.isEmpty) {
      stderr.writeln('error: verification failed: blank line found');
      exit(1);
    }
    if (!_lowercaseLettersOnly.hasMatch(line)) {
      stderr.writeln('error: verification failed: malformed entry "$line"');
      exit(1);
    }
    if (line.length != expectedLength) {
      stderr.writeln(
        'error: verification failed: "$line" has length ${line.length}, '
        'expected $expectedLength',
      );
      exit(1);
    }
    if (!seen.add(line)) {
      stderr.writeln('error: verification failed: duplicate entry "$line"');
      exit(1);
    }
    if (previous != null && previous.compareTo(line) > 0) {
      stderr.writeln(
        'error: verification failed: "$previous" sorts after "$line"',
      );
      exit(1);
    }
    previous = line;
  }
}

void _printSummary({
  required _SourceResult allowedSource,
  required _SourceResult secretSource,
  required Map<String, int> outputCounts,
  required Map<int, int> excludedCountByLength,
}) {
  print('Word list generation summary');
  print('=============================');
  print('Source files:');
  print(
    '  ${allowedSource.path}: ${allowedSource.rawLineCount} lines read, '
    '${allowedSource.invalidCount} invalid entries removed, '
    '${allowedSource.duplicateCount} duplicates removed',
  );
  print(
    '  ${secretSource.path}: ${secretSource.rawLineCount} lines read, '
    '${secretSource.invalidCount} invalid entries removed, '
    '${secretSource.duplicateCount} duplicates removed',
  );
  print('');
  print('Generated files:');
  for (final length in supportedLengths) {
    print(
      '  allowed_words_$length.txt: ${outputCounts['allowed_words_$length.txt']} words',
    );
    print(
      '  secret_words_$length.txt: ${outputCounts['secret_words_$length.txt']} words '
      '(${excludedCountByLength[length]} common words excluded: not in allowed set)',
    );
  }
  print('');
  print(
    'All generated files verified: lowercase a-z only, exact length, '
    'sorted, deduplicated, secrets subset of allowed.',
  );
}
