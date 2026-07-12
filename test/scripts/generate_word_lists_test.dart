// Tests the pure, logic-bearing functions extracted from
// scripts/generate_word_lists.dart directly, rather than shelling out to
// the script repeatedly — see the file's own top-of-file comment.

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/generate_word_lists.dart';

void main() {
  group('normalizeLine', () {
    test('trims and lowercases a valid line', () {
      final line = normalizeLine('  CraNe  ');
      expect(line.word, 'crane');
      expect(line.wasBlank, isFalse);
    });

    test('flags a blank line without counting it as invalid', () {
      final line = normalizeLine('   ');
      expect(line.wasBlank, isTrue);
      expect(line.word, isNull);
    });

    test('rejects a line with digits', () {
      final line = normalizeLine('cr4ne');
      expect(line.wasBlank, isFalse);
      expect(line.word, isNull);
    });

    test('rejects a line with punctuation or spaces', () {
      expect(normalizeLine("can't").word, isNull);
      expect(normalizeLine('two words').word, isNull);
    });
  });

  group('buildSortedSource', () {
    test('sorts and deduplicates per length, silently dropping unsupported '
        'lengths', () {
      final result = buildSortedSource(
        [
          'crane',
          'apple',
          'crane', // duplicate
          'lace', // unsupported length here
          'INVALID1',
        ],
        [5],
      );

      expect(result.wordsOfLength(5), ['apple', 'crane']);
      expect(result.duplicateCount, 1);
      expect(result.invalidCount, 1);
    });
  });

  group('buildRankedSource', () {
    test('preserves first-occurrence (frequency-rank) order', () {
      final result = buildRankedSource(['crane', 'apple', 'zebra'], [5]);
      expect(result.wordsOfLength(5), ['crane', 'apple', 'zebra']);
    });

    test('deduplicates, keeping only the first occurrence', () {
      final result = buildRankedSource(['crane', 'apple', 'crane'], [5]);
      expect(result.wordsOfLength(5), ['crane', 'apple']);
      expect(result.duplicateCount, 1);
    });

    test('drops blank lines without counting them as invalid', () {
      final result = buildRankedSource(['crane', '', '  '], [5]);
      expect(result.wordsOfLength(5), ['crane']);
      expect(result.invalidCount, 0);
    });

    test('counts non-blank invalid lines', () {
      final result = buildRankedSource(['crane', 'cr4ne', "can't"], [5]);
      expect(result.invalidCount, 2);
    });

    test('silently drops lines of an unsupported length', () {
      final result = buildRankedSource(['crane', 'lace'], [5]);
      expect(result.wordsOfLength(4), isEmpty);
      expect(result.invalidCount, 0);
      expect(result.duplicateCount, 0);
    });
  });

  group('eligibleSecretCandidates', () {
    test('keeps only words present in the allowed set, preserving order', () {
      final eligible = eligibleSecretCandidates(
        ['crane', 'zesty', 'apple'],
        {'crane', 'apple'},
      );
      expect(eligible, ['crane', 'apple']);
    });
  });

  group('partitionByDifficulty', () {
    test('splits into a top quarter, bottom quarter, and middle half', () {
      // 20 words: quarter = 5.
      final ranked = List.generate(
        20,
        (i) => 'w${i.toString().padLeft(2, '0')}',
      );
      final pools = partitionByDifficulty(ranked);

      expect(pools.easy, ranked.sublist(0, 5));
      expect(pools.hard, ranked.sublist(15, 20));
      expect(pools.common, ranked.sublist(5, 15));
    });

    test('pools are disjoint', () {
      final ranked = List.generate(37, (i) => 'w$i');
      final pools = partitionByDifficulty(ranked);
      final easySet = pools.easy.toSet();
      final commonSet = pools.common.toSet();
      final hardSet = pools.hard.toSet();

      expect(easySet.intersection(commonSet), isEmpty);
      expect(easySet.intersection(hardSet), isEmpty);
      expect(commonSet.intersection(hardSet), isEmpty);
    });

    test('the concatenation of all three pools equals the ranked eligible '
        'input, in order', () {
      final ranked = List.generate(37, (i) => 'w$i');
      final pools = partitionByDifficulty(ranked);
      expect([...pools.easy, ...pools.common, ...pools.hard], ranked);
    });

    test('handles remainders from integer division by giving them to '
        'common', () {
      // 22 words: quarter = 5 (22 ~/ 4), so common gets 12 (> half).
      final ranked = List.generate(22, (i) => 'w$i');
      final pools = partitionByDifficulty(ranked);
      expect(pools.easy.length, 5);
      expect(pools.hard.length, 5);
      expect(pools.common.length, 12);
    });

    test('deterministic: repeated calls with the same input produce the '
        'same output', () {
      final ranked = List.generate(37, (i) => 'w$i');
      final first = partitionByDifficulty(ranked);
      final second = partitionByDifficulty(ranked);
      expect(first.easy, second.easy);
      expect(first.common, second.common);
      expect(first.hard, second.hard);
    });
  });

  group('formatWordListFile', () {
    test('ends with exactly one trailing newline for a non-empty list', () {
      final contents = formatWordListFile(['apple', 'crane']);
      expect(contents, 'apple\ncrane\n');
    });

    test('is empty for a zero-entry list', () {
      expect(formatWordListFile(const []), '');
    });
  });

  group('wordListFormatViolation', () {
    test('accepts well-formed, sorted, deduplicated lines', () {
      expect(wordListFormatViolation(['apple', 'crane'], 5), isNull);
    });

    test('rejects a blank line', () {
      expect(wordListFormatViolation(['apple', ''], 5), isNotNull);
    });

    test('rejects a wrong-length entry', () {
      expect(wordListFormatViolation(['apple', 'lace'], 5), isNotNull);
    });

    test('rejects an out-of-order entry', () {
      expect(wordListFormatViolation(['crane', 'apple'], 5), isNotNull);
    });

    test('rejects a duplicate entry', () {
      expect(wordListFormatViolation(['apple', 'apple'], 5), isNotNull);
    });

    test('rejects uppercase or non-letter content', () {
      expect(wordListFormatViolation(['Apple'], 5), isNotNull);
      expect(wordListFormatViolation(['ap9le'], 5), isNotNull);
    });
  });

  group('end-to-end pipeline on an in-memory fixture', () {
    // Letters-only 3-letter fixture words (normalizeLine rejects digits),
    // e.g. 'aaa', 'aab', ... — 40 distinct values fit comfortably before
    // the first letter needs to roll over.
    String fixtureWord(int i) {
      final first = String.fromCharCode(97 + (i ~/ 26));
      final second = String.fromCharCode(97 + (i % 26));
      return 'a$first$second';
    }

    test('produces alphabetically sorted, subset, disjoint difficulty '
        'pools', () {
      // 12,000-ish realistic scale would be slow to fabricate here; a
      // smaller fixture exercises the same code paths.
      final allowedRaw = [for (var i = 0; i < 40; i++) fixtureWord(i)];
      final rankedRaw = [for (var i = 0; i < 40; i++) fixtureWord(i)]
        ..shuffle(); // frequency order is independent of allowed order

      final allowedSource = buildSortedSource(allowedRaw, [3]);
      final allowedSet = allowedSource.wordsOfLength(3).toSet();
      expect(allowedSet.length, 40);

      final rankedSource = buildRankedSource(rankedRaw, [3]);
      final eligible = eligibleSecretCandidates(
        rankedSource.wordsOfLength(3),
        allowedSet,
      );
      expect(eligible.toSet(), allowedSet);

      final pools = partitionByDifficulty(eligible);
      for (final pool in [pools.easy, pools.common, pools.hard]) {
        final sorted = [...pool]..sort();
        expect(wordListFormatViolation(sorted, 3), isNull);
        for (final word in sorted) {
          expect(allowedSet.contains(word), isTrue);
        }
      }
    });
  });
}
