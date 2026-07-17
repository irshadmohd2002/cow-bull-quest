import 'dart:collection';

import 'revealed_hint.dart';

/// The hints revealed so far in one game.
///
/// Immutable — [withHint] returns a new instance rather than mutating this
/// one — and always reset to [initial] whenever a new game starts (see
/// `GameController.startGame`). Never persisted across app restarts: this
/// app does not persist active games at all, and per Milestone 14 hint
/// state is only ever required to survive while the game remains open in
/// memory, not across process death.
class HintState {
  const HintState({List<RevealedHint> revealedHints = const []})
    : _revealedHints = revealedHints; // ignore: prefer_initializing_formals

  /// The state a freshly started game begins with: no hints used yet.
  static const HintState initial = HintState();

  final List<RevealedHint> _revealedHints;

  /// The hints revealed so far, oldest first. Unmodifiable.
  UnmodifiableListView<RevealedHint> get revealedHints =>
      UnmodifiableListView(_revealedHints);

  /// The number of hints used so far this game.
  int get hintsUsed => _revealedHints.length;

  /// Returns a new state with [hint] appended; leaves this instance
  /// untouched.
  HintState withHint(RevealedHint hint) =>
      HintState(revealedHints: [..._revealedHints, hint]);
}
