import 'package:cowbullgame/core/feedback/game_feedback.dart';

/// In-memory [GameFeedback] fake so `GameController` tests can assert
/// exactly which gameplay outcomes were reported — and in what order —
/// without depending on real audio/haptic services.
class FakeGameFeedback implements GameFeedback {
  /// Every method call, in call order (e.g. `'onValidGuess'`,
  /// `'onHintRevealed(paid: true)'`).
  final List<String> calls = [];

  @override
  void onValidGuess() => calls.add('onValidGuess');

  @override
  void onInvalidGuess() => calls.add('onInvalidGuess');

  @override
  void onHintRevealed({required bool paid}) =>
      calls.add('onHintRevealed(paid: $paid)');

  @override
  void onGameWon() => calls.add('onGameWon');

  @override
  void onGameLost() => calls.add('onGameLost');
}
