/// One hint revealed to the player during a game: a single correct letter,
/// together with its exact position in the secret word.
///
/// Deliberately does not carry a cost or a "was this free" flag — hints are
/// purely a reveal of domain fact; pricing is [HintPolicy]'s concern
/// (`services/hint_policy.dart`), not this model's.
class RevealedHint {
  const RevealedHint({required this.position, required this.letter});

  /// 0-based index into the secret word.
  final int position;

  /// The lowercase letter at [position] in the secret word.
  final String letter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RevealedHint &&
          other.position == position &&
          other.letter == letter);

  @override
  int get hashCode => Object.hash(position, letter);

  @override
  String toString() => 'RevealedHint(position: $position, letter: $letter)';
}
