import 'package:cowbullgame/features/game/services/completion_id_generator.dart';

/// Deterministic [CompletionIdGenerator] fake: returns [ids] in order, one
/// per call. Use [FakeCompletionIdGenerator.constant] when a test wants
/// every call to deliberately return the same value (e.g. to prove that
/// reusing one ID across distinct games is the test double's choice, not
/// something [GameController] itself does or guards against).
class FakeCompletionIdGenerator implements CompletionIdGenerator {
  FakeCompletionIdGenerator(this._ids);

  /// An id generator that always returns [id], however many times it is
  /// called.
  factory FakeCompletionIdGenerator.constant(String id) =>
      FakeCompletionIdGenerator(List.generate(1000, (_) => id));

  final List<String> _ids;

  /// The number of times [generate] has been called.
  int callCount = 0;

  /// Every id returned so far, in call order.
  final List<String> generatedIds = [];

  @override
  String generate() {
    final id = _ids[callCount];
    callCount++;
    generatedIds.add(id);
    return id;
  }
}
