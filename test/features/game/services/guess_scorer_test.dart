import 'package:cowbullgame/features/game/models/guess_result.dart';
import 'package:cowbullgame/features/game/services/guess_scorer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scorer = GuessScorer();

  group('GuessScorer', () {
    test('all bulls when guess matches secret exactly', () {
      final result = scorer.score(secretWord: 'crane', guess: 'crane');
      expect(result, GuessResult(bulls: 5, cows: 0));
    });

    test('all cows when letters match but every position is wrong', () {
      // secret: cares (c,a,r,e,s), guess: scare (s,c,a,r,e) is a cyclic
      // shift of the secret by one position, so every letter is shared but
      // no guess letter sits in its secret position.
      final result = scorer.score(secretWord: 'cares', guess: 'scare');
      expect(result, GuessResult(bulls: 0, cows: 5));
    });

    test('no matches when no letters are shared', () {
      final result = scorer.score(secretWord: 'abcde', guess: 'fghij');
      expect(result, GuessResult(bulls: 0, cows: 0));
    });

    test('mixed bulls and cows', () {
      // secret: apple, guess: angle
      // index 0: a==a -> bull
      // index 1: p vs n -> no match
      // index 2: p vs g -> no match
      // index 3: l vs l -> bull
      // index 4: e==e -> bull
      // Remaining unmatched: secret {p,p} guess {n,g} -> no cows.
      final result = scorer.score(secretWord: 'apple', guess: 'angle');
      expect(result, GuessResult(bulls: 3, cows: 0));
    });

    test('repeated letters in the secret are not over-credited', () {
      // secret: 'sassy' (s,a,s,s,y), guess: 'soapy' (s,o,a,p,y)
      // index 0: s==s -> bull
      // index 4: y==y -> bull
      // Remaining secret letters (unmatched): a,s,s
      // Remaining guess letters (unmatched): o,a,p
      // 'a' remains in secret once -> 1 cow. 'o' and 'p' don't appear in
      // the remaining secret letters -> no further cows.
      final result = scorer.score(secretWord: 'sassy', guess: 'soapy');
      expect(result, GuessResult(bulls: 2, cows: 1));
    });

    test('repeated letters in the guess are capped by secret occurrences', () {
      // secret: 'bass' (b,a,s,s) has exactly two 's's, both of which land
      // as bulls at indices 2 and 3 against guess 'ssss'.
      // Remaining secret letters (unmatched): b,a — no 's' left at all.
      // Remaining guess letters (unmatched): s,s — but the secret has no
      // more 's's to offer, so neither extra 's' becomes a cow.
      final result = scorer.score(secretWord: 'bass', guess: 'ssss');
      expect(result, GuessResult(bulls: 2, cows: 0));
    });

    test('repeated letters in both secret and guess are capped correctly', () {
      // secret: 'sassy' has two 's's (plus a,s,s,y). guess: 'seeds' has one
      // 's' at a mismatched position.
      // index 0: s==s -> bull (position 0 in both).
      // Remaining secret (unmatched): a,s,s,y
      // Remaining guess (unmatched): e,e,d,s
      // The single remaining guess 's' matches one of the two remaining
      // secret 's's -> 1 cow, capped at 1 even though secret still has an
      // extra 's' left over (no more guess 's' to consume it).
      final result = scorer.score(secretWord: 'sassy', guess: 'seeds');
      expect(result, GuessResult(bulls: 1, cows: 1));
    });

    test('a letter is never counted more times than it appears in secret', () {
      // secret: 'pizza' has one 'z' among its 5 letters at index 2 & 3
      // Actually 'pizza' = p,i,z,z,a -> two 'z's. guess: 'zzzzz' has five.
      // index 2: z==z -> bull. index 3: z==z -> bull.
      // Remaining secret (unmatched): p,i,a
      // Remaining guess (unmatched): z,z,z (indices 0,1,4)
      // None of the remaining secret letters are 'z' -> 0 cows, even
      // though the guess offers three more 'z's.
      final result = scorer.score(secretWord: 'pizza', guess: 'zzzzz');
      expect(result, GuessResult(bulls: 2, cows: 0));
    });

    test('scoring is case-insensitive', () {
      final result = scorer.score(secretWord: 'Crane', guess: 'CRANE');
      expect(result, GuessResult(bulls: 5, cows: 0));
    });

    test('throws ArgumentError when guess and secret lengths differ', () {
      expect(
        () => scorer.score(secretWord: 'crane', guess: 'cranes'),
        throwsArgumentError,
      );
    });
  });
}
