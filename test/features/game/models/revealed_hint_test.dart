import 'package:cowbullgame/features/game/models/revealed_hint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevealedHint equality', () {
    test('two hints with the same position and letter are equal', () {
      const a = RevealedHint(position: 1, letter: 'a');
      const b = RevealedHint(position: 1, letter: 'a');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different position makes hints unequal', () {
      const a = RevealedHint(position: 1, letter: 'a');
      const b = RevealedHint(position: 2, letter: 'a');
      expect(a, isNot(b));
    });

    test('a different letter makes hints unequal', () {
      const a = RevealedHint(position: 1, letter: 'a');
      const b = RevealedHint(position: 1, letter: 'b');
      expect(a, isNot(b));
    });
  });

  group('RevealedHint fields', () {
    test('exposes the position and letter given at construction', () {
      const hint = RevealedHint(position: 2, letter: 'z');
      expect(hint.position, 2);
      expect(hint.letter, 'z');
    });
  });
}
