import 'package:cowbullgame/features/game/data/word_list_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = WordListParser();

  group('WordListParser valid content', () {
    test('parses a pre-sorted LF-terminated file', () {
      final result = parser.parse('apple\nbread\ncrane\n', wordLength: 5);
      expect(result, ['apple', 'bread', 'crane']);
    });

    test('parses a pre-sorted CRLF-terminated file', () {
      final result = parser.parse('apple\r\nbread\r\ncrane\r\n', wordLength: 5);
      expect(result, ['apple', 'bread', 'crane']);
    });

    test('preserves the original (already-sorted) file order', () {
      final result = parser.parse('apple\nbread\ncrane\n', wordLength: 5);
      expect(result, ['apple', 'bread', 'crane']); // not just unordered-equal
    });

    test('treats completely empty content as a valid zero-entry list', () {
      expect(parser.parse('', wordLength: 5), isEmpty);
    });

    test('returns an unmodifiable list', () {
      final result = parser.parse('apple\n', wordLength: 5);
      expect(() => result.add('extra'), throwsUnsupportedError);
    });
  });

  group('WordListParser strict rejection', () {
    test('rejects an uppercase entry rather than lowercasing it', () {
      expect(
        () => parser.parse('Apple\n', wordLength: 5),
        throwsA(isA<WordListFormatException>()),
      );
    });

    test('rejects a leading-whitespace entry rather than trimming it', () {
      expect(
        () => parser.parse(' apple\n', wordLength: 5),
        throwsA(isA<WordListFormatException>()),
      );
    });

    test('rejects a trailing-whitespace entry rather than trimming it', () {
      expect(
        () => parser.parse('apple \n', wordLength: 5),
        throwsA(isA<WordListFormatException>()),
      );
    });

    test('rejects a duplicate entry rather than deduplicating it', () {
      expect(
        () => parser.parse('apple\napple\n', wordLength: 5),
        throwsA(
          isA<WordListFormatException>().having(
            (e) => e.message,
            'message',
            contains('duplicate'),
          ),
        ),
      );
    });

    test('rejects entries that are not strictly ascending sorted', () {
      expect(
        () => parser.parse('bread\napple\n', wordLength: 5),
        throwsA(
          isA<WordListFormatException>().having(
            (e) => e.message,
            'message',
            contains('order'),
          ),
        ),
      );
    });

    test('rejects an internal blank line', () {
      expect(
        () => parser.parse('apple\n\nbread\n', wordLength: 5),
        throwsA(
          isA<WordListFormatException>().having(
            (e) => e.message,
            'message',
            contains('blank line'),
          ),
        ),
      );
    });

    test('rejects content with no required trailing newline', () {
      expect(
        () => parser.parse('apple\nbread', wordLength: 5),
        throwsA(
          isA<WordListFormatException>().having(
            (e) => e.message,
            'message',
            contains('trailing newline'),
          ),
        ),
      );
    });

    test('rejects a lone newline as a blank line, not an empty list', () {
      // Distinguishes the "empty content = zero entries" contract from a
      // file that has a single blank line and nothing else.
      expect(
        () => parser.parse('\n', wordLength: 5),
        throwsA(isA<WordListFormatException>()),
      );
    });

    test('rejects an entry of the wrong length', () {
      expect(
        () => parser.parse('cat\n', wordLength: 5),
        throwsA(isA<WordListFormatException>()),
      );
    });

    test('rejects an entry with punctuation', () {
      expect(
        () => parser.parse("cra'e\n", wordLength: 5),
        throwsA(isA<WordListFormatException>()),
      );
    });

    test('rejects an entry with digits', () {
      expect(
        () => parser.parse('cr4ne\n', wordLength: 5),
        throwsA(isA<WordListFormatException>()),
      );
    });

    test('rejects an entry with internal spaces', () {
      expect(
        () => parser.parse('cr ne\n', wordLength: 5),
        throwsA(isA<WordListFormatException>()),
      );
    });

    test('malformed content fails the whole parse, not just the bad line', () {
      expect(
        () => parser.parse('apple\nbread\ncr4ne\ncrane\n', wordLength: 5),
        throwsA(isA<WordListFormatException>()),
      );
    });
  });

  group('WordListParser error context', () {
    test('includes the source and 1-based line number in the message', () {
      expect(
        () => parser.parse(
          'apple\nBread\n',
          wordLength: 5,
          source: 'allowed_words_5.txt',
        ),
        throwsA(
          isA<WordListFormatException>().having(
            (e) => e.message,
            'message',
            contains('allowed_words_5.txt:2'),
          ),
        ),
      );
    });
  });
}
