import 'dart:math';

/// The number of random bytes each generated ID is derived from (128 bits) —
/// enough that two independently generated IDs colliding is not a practical
/// concern, unlike e.g. a Flutter `Key`'s identity hash (only tens of bits).
const int _idByteLength = 16;

/// Generates a stable, collision-resistant identifier for one completed
/// game, used so a statistics repository can tell two distinct completions
/// apart (and reject an accidental duplicate) without ever touching the
/// secret word or guess history.
///
/// Kept feature-local to `game` (rather than under `statistics`) since
/// [GameController] — which must generate the ID at the moment a game
/// starts, entirely independently of whether statistics exist — is the
/// only thing that calls it; the `statistics` feature only ever receives an
/// already-generated ID as a plain `String` via the completion callback.
abstract class CompletionIdGenerator {
  /// Returns a newly generated ID. Every call must return a value that
  /// cannot practically collide with any other call's result.
  String generate();
}

/// The real [CompletionIdGenerator]: 128 bits from [Random.secure] — an
/// OS-backed cryptographic random source, not the default (seedable,
/// non-cryptographic) [Random] — encoded as a fixed-width 32-character
/// lowercase hexadecimal string. Never derived from a timestamp alone,
/// which two games completing within the same clock tick could share.
class SecureRandomCompletionIdGenerator implements CompletionIdGenerator {
  const SecureRandomCompletionIdGenerator();

  @override
  String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(_idByteLength, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
