import 'package:cowbullgame/features/game/controllers/game_controller_state.dart';
import 'package:cowbullgame/features/game/models/game_session.dart';
import 'package:cowbullgame/features/game/models/game_status.dart';
import 'package:cowbullgame/features/game/models/hint_state.dart';
import 'package:cowbullgame/features/game/models/revealed_hint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GameSession inProgressSession() => GameSession.start('lace', maxAttempts: 10);

  GameSession wonSession() =>
      inProgressSession().copyWith(status: GameStatus.won);

  GameSession lostSession() =>
      inProgressSession().copyWith(status: GameStatus.lost);

  group('GameActive invariant', () {
    test('constructs for an in-progress session view', () {
      final view = GameSessionView.fromSession(inProgressSession());
      expect(() => GameActive(view: view), returnsNormally);
    });

    test('throws ArgumentError for a won session view', () {
      final view = GameSessionView.fromSession(wonSession());
      expect(() => GameActive(view: view), throwsArgumentError);
    });

    test('throws ArgumentError for a lost session view', () {
      final view = GameSessionView.fromSession(lostSession());
      expect(() => GameActive(view: view), throwsArgumentError);
    });
  });

  group('GameActive hintState', () {
    test('defaults to HintState.initial when not supplied', () {
      final view = GameSessionView.fromSession(inProgressSession());
      final active = GameActive(view: view);
      expect(active.hintState.hintsUsed, 0);
    });

    test('carries the hint state supplied at construction', () {
      final view = GameSessionView.fromSession(inProgressSession());
      final hintState = HintState.initial.withHint(
        const RevealedHint(position: 0, letter: 'l'),
      );
      final active = GameActive(view: view, hintState: hintState);
      expect(active.hintState.hintsUsed, 1);
      expect(active.hintState.revealedHints, [
        const RevealedHint(position: 0, letter: 'l'),
      ]);
    });
  });

  group('GameCompleted invariant', () {
    test('constructs for a won session', () {
      expect(() => GameCompleted(wonSession()), returnsNormally);
    });

    test('constructs for a lost session', () {
      expect(() => GameCompleted(lostSession()), returnsNormally);
    });

    test('throws ArgumentError for an in-progress session', () {
      expect(() => GameCompleted(inProgressSession()), throwsArgumentError);
    });
  });
}
