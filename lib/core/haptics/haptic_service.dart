/// Triggers device haptic feedback for important app actions.
///
/// A pure playback abstraction, mirroring [AudioService]'s role for sound:
/// it knows nothing about whether haptics are enabled or which game event
/// is occurring — gating on user preference and mapping game events to a
/// specific call is [AudioFeedbackCoordinator]'s job. App code and features
/// depend on this interface rather than on `package:flutter/services.dart`'s
/// `HapticFeedback` directly, so it stays swappable and tests can use a fake
/// with no platform channels.
///
/// Every method must never throw — implementations are responsible for
/// catching their own failures internally, since a device or platform that
/// doesn't support a given haptic must never break the triggering action.
abstract class HapticService {
  /// A light tick, used for a discrete selection (e.g. choosing a
  /// difficulty).
  Future<void> selectionClick();

  /// A light, single impact, used for a routine positive confirmation (e.g.
  /// a valid guess, a free hint).
  Future<void> lightImpact();

  /// A medium, single impact, used for a more significant confirmation (e.g.
  /// a paid hint).
  Future<void> mediumImpact();

  /// A warning-style impact, used for a negative/rejected event (e.g. an
  /// invalid guess).
  Future<void> warning();

  /// A positive, attention-getting sequence, used for a strong success
  /// event (e.g. winning a game).
  Future<void> success();
}
