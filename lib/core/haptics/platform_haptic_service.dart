import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'haptic_service.dart';

/// The real [HapticService], backed entirely by Flutter's built-in
/// [HapticFeedback] — this app adds no separate haptics package.
///
/// [HapticFeedback] exposes only [HapticFeedback.selectionClick],
/// [HapticFeedback.lightImpact], [HapticFeedback.mediumImpact],
/// [HapticFeedback.heavyImpact], and [HapticFeedback.vibrate]; there is no
/// built-in "warning" or "success" pattern. [warning] uses
/// [HapticFeedback.heavyImpact] — the strongest single built-in impact,
/// and the safest available way to make a negative event feel distinct
/// from [lightImpact]/[mediumImpact] without a custom vibration pattern.
/// [success] composes two short, built-in impacts in sequence (medium then
/// light) — "a suitable built-in sequence" — to feel more celebratory than
/// any single call alone.
///
/// Every method swallows its own failure (logging in debug mode only)
/// rather than throwing: an unsupported haptic on a given device, or a
/// platform-channel error, must never break the action that triggered it.
class PlatformHapticService implements HapticService {
  const PlatformHapticService();

  void _logFailure(String action, Object error) {
    if (kDebugMode) {
      debugPrint('PlatformHapticService: $action failed: $error');
    }
  }

  Future<void> _guard(String action, Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      _logFailure(action, error);
    }
  }

  @override
  Future<void> selectionClick() =>
      _guard('selectionClick', HapticFeedback.selectionClick);

  @override
  Future<void> lightImpact() =>
      _guard('lightImpact', HapticFeedback.lightImpact);

  @override
  Future<void> mediumImpact() =>
      _guard('mediumImpact', HapticFeedback.mediumImpact);

  @override
  Future<void> warning() => _guard('warning', HapticFeedback.heavyImpact);

  @override
  Future<void> success() => _guard('success', () async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  });
}
