import 'package:cowbullgame/features/game/models/hint_state.dart';
import 'package:cowbullgame/features/game/models/revealed_hint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HintState.initial', () {
    test('starts with no hints used', () {
      expect(HintState.initial.hintsUsed, 0);
      expect(HintState.initial.revealedHints, isEmpty);
    });
  });

  group('HintState.withHint', () {
    test('appends a hint and increments hintsUsed', () {
      const hint = RevealedHint(position: 1, letter: 'a');
      final updated = HintState.initial.withHint(hint);

      expect(updated.hintsUsed, 1);
      expect(updated.revealedHints, [hint]);
    });

    test('leaves the original instance untouched', () {
      const hint = RevealedHint(position: 1, letter: 'a');
      final original = HintState.initial;
      original.withHint(hint);

      expect(original.hintsUsed, 0);
      expect(original.revealedHints, isEmpty);
    });

    test('accumulates multiple hints in the order used', () {
      const first = RevealedHint(position: 0, letter: 'l');
      const second = RevealedHint(position: 2, letter: 'c');
      final updated = HintState.initial.withHint(first).withHint(second);

      expect(updated.hintsUsed, 2);
      expect(updated.revealedHints, [first, second]);
    });
  });

  group('HintState.revealedHints', () {
    test('is unmodifiable', () {
      const hint = RevealedHint(position: 0, letter: 'l');
      final state = HintState.initial.withHint(hint);

      expect(() => state.revealedHints.add(hint), throwsUnsupportedError);
    });
  });
}
