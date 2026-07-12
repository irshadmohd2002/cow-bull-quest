import '../../../core/exceptions.dart';

final RegExp _lowercaseLettersOnly = RegExp(r'^[a-z]+$');

/// Thrown when the text contents of a generated word-list asset do not
/// satisfy the strict format [WordListParser] requires.
class WordListFormatException extends AppException {
  const WordListFormatException(super.message);
}

/// Parses the raw text contents of a generated word-list asset (see
/// `docs/word_lists.md`) into an exact-length, deduplicated,
/// ascending-sorted, immutable list of words, in file order.
///
/// Generated assets are controlled build artifacts produced by
/// `scripts/generate_word_lists.dart`, which already normalizes, filters,
/// deduplicates, and sorts raw source data. This parser therefore
/// **validates rather than repairs**: it accepts only content that is
/// already exactly correct and throws [WordListFormatException] on the
/// first violation found, so a broken generation step (or a hand-edited
/// asset) is caught immediately instead of being silently "fixed" at load
/// time. It never trims, lowercases, sorts, or deduplicates its input.
///
/// Format contract for the parsed content:
/// - one entry per line, each matching `^[a-z]+$` and exactly the
///   requested word length — no surrounding whitespace, no uppercase, no
///   digits, no punctuation;
/// - entries strictly ascending in alphabetical order, with no duplicates;
/// - no blank lines, including no leading or embedded blank line;
/// - the content **must** end with exactly one trailing newline, per the
///   generated-file spec in `docs/word_lists.md`, with one exception:
///   completely empty content is accepted as a valid zero-entry list,
///   because `scripts/generate_word_lists.dart` writes an empty word list
///   as a zero-byte file, not as a lone newline. A non-empty file that
///   doesn't end in a newline is rejected rather than silently accepted,
///   since a truncated generated file is exactly the kind of pipeline
///   defect this parser exists to catch.
class WordListParser {
  const WordListParser();

  /// Parses [contents] as a word list of exactly [wordLength] letters.
  ///
  /// [source] identifies the asset being parsed (typically its asset
  /// path) and is included, together with the 1-based line number where
  /// relevant, in any [WordListFormatException] thrown.
  List<String> parse(
    String contents, {
    required int wordLength,
    String source = 'word list',
  }) {
    if (contents.isEmpty) return const [];

    if (!contents.endsWith('\n')) {
      throw WordListFormatException(
        '$source: missing required trailing newline',
      );
    }

    final lines = contents.replaceAll('\r\n', '\n').split('\n');
    // Splitting content that ends in '\n' always yields one trailing
    // empty string for that required newline; drop only that artifact.
    final entryLines = lines.sublist(0, lines.length - 1);

    final words = <String>[];
    final seen = <String>{};
    String? previous;

    for (var i = 0; i < entryLines.length; i++) {
      final line = entryLines[i];
      final lineNumber = i + 1;

      if (line.isEmpty) {
        throw WordListFormatException(
          '$source:$lineNumber: blank line is not allowed',
        );
      }
      if (!_lowercaseLettersOnly.hasMatch(line)) {
        throw WordListFormatException(
          '$source:$lineNumber: entry "$line" must contain only lowercase '
          'letters a-z with no surrounding whitespace',
        );
      }
      if (line.length != wordLength) {
        throw WordListFormatException(
          '$source:$lineNumber: entry "$line" has length ${line.length}, '
          'expected $wordLength',
        );
      }
      if (!seen.add(line)) {
        throw WordListFormatException(
          '$source:$lineNumber: duplicate entry "$line"',
        );
      }
      if (previous != null && line.compareTo(previous) <= 0) {
        throw WordListFormatException(
          '$source:$lineNumber: entry "$line" is out of alphabetical '
          'order (must sort strictly after "$previous")',
        );
      }

      words.add(line);
      previous = line;
    }

    return List.unmodifiable(words);
  }
}
