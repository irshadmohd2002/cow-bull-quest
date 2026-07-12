/// Base type for typed failures raised by this app's `services` and `data`
/// layers, so calling code can catch or match on a stable app-wide type
/// instead of a bare [Exception].
abstract class AppException implements Exception {
  const AppException(this.message);

  /// Human-readable detail describing what failed.
  final String message;

  @override
  String toString() => message;
}
