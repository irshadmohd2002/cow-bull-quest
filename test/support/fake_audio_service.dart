import 'package:cowbullgame/core/audio/audio_service.dart';

/// In-memory [AudioService] fake so tests can assert exactly which sounds
/// were requested — and in what order — without ever touching a real
/// player or platform channel.
class FakeAudioService implements AudioService {
  /// Every method call, in call order (e.g. `'playWin'`, `'startMusic'`).
  final List<String> calls = [];

  /// If set, every call to the method whose name matches a key in this map
  /// throws the given error instead of recording normally — lets a test
  /// force a playback failure to prove it's swallowed.
  final Map<String, Object> failWith = {};

  bool disposed = false;

  Future<void> _record(String name) async {
    calls.add(name);
    final error = failWith[name];
    if (error != null) throw error;
  }

  @override
  Future<void> playButtonTap() => _record('playButtonTap');

  @override
  Future<void> playInvalidGuess() => _record('playInvalidGuess');

  @override
  Future<void> playHintUsed() => _record('playHintUsed');

  @override
  Future<void> playCoinSpent() => _record('playCoinSpent');

  @override
  Future<void> playWin() => _record('playWin');

  @override
  Future<void> playLoss() => _record('playLoss');

  @override
  Future<void> startMusic() => _record('startMusic');

  @override
  Future<void> pauseMusic() => _record('pauseMusic');

  @override
  Future<void> resumeMusic() => _record('resumeMusic');

  @override
  Future<void> stopMusic() => _record('stopMusic');

  @override
  Future<void> dispose() async {
    disposed = true;
    await _record('dispose');
  }
}
