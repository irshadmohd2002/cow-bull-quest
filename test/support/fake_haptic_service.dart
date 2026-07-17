import 'package:cowbullgame/core/haptics/haptic_service.dart';

/// In-memory [HapticService] fake so tests can assert exactly which haptics
/// were requested — and in what order — without ever invoking a real
/// device haptic.
class FakeHapticService implements HapticService {
  /// Every method call, in call order.
  final List<String> calls = [];

  /// If set, every call to the method whose name matches a key in this map
  /// throws the given error instead of recording normally.
  final Map<String, Object> failWith = {};

  Future<void> _record(String name) async {
    calls.add(name);
    final error = failWith[name];
    if (error != null) throw error;
  }

  @override
  Future<void> selectionClick() => _record('selectionClick');

  @override
  Future<void> lightImpact() => _record('lightImpact');

  @override
  Future<void> mediumImpact() => _record('mediumImpact');

  @override
  Future<void> warning() => _record('warning');

  @override
  Future<void> success() => _record('success');
}
