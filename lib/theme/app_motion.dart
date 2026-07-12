import 'package:flutter/material.dart';

/// Shared, short built-in-animation durations and curves.
///
/// Kept intentionally brief per the project's animation constraints (Milestone
/// 8, Part 8): meaningful and short, never blocking input, never requiring
/// golden-timing assumptions. No external animation package is used anywhere
/// this is consumed.
abstract final class AppMotion {
  /// Duration for small, local content swaps (e.g. a selection description
  /// or a validation message changing).
  static const Duration fast = Duration(milliseconds: 150);

  /// Duration for slightly larger size/layout transitions.
  static const Duration standard = Duration(milliseconds: 200);

  static const Curve curve = Curves.easeOut;

  /// Resolves [duration] against [context]'s reduced-motion preference.
  ///
  /// Returns [Duration.zero] when `MediaQuery.disableAnimationsOf(context)`
  /// is true — every built-in animated widget (`AnimatedSwitcher`,
  /// `AnimatedContainer`, `TweenAnimationBuilder`, etc.) treats a zero
  /// duration as "jump straight to the end state", so no animation
  /// controller is left ticking and no interaction is delayed. Returns
  /// [duration] unchanged otherwise. Every animation added in Milestone 8
  /// resolves its duration through this method rather than using
  /// [fast]/[standard] directly.
  static Duration durationFor(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}
