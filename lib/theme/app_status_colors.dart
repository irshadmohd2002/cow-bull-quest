import 'package:flutter/material.dart';

/// Brand status colors with no equivalent role in Material 3's
/// [ColorScheme] (which has `error` but no `success`).
///
/// Registered on both [ThemeData.extensions] in [AppTheme] and read via
/// `Theme.of(context).extension<AppStatusColors>()!`. [success] is the
/// brand's gold accent — used sparingly, only for premium/reward moments
/// (the Game screen's win outcome, the Statistics win-rate figure), never a
/// button or label color. Kept to exactly the two roles actually consumed
/// rather than a speculative broader token set.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({required this.success, required this.onSuccess});

  final Color success;
  final Color onSuccess;

  @override
  AppStatusColors copyWith({Color? success, Color? onSuccess}) =>
      AppStatusColors(
        success: success ?? this.success,
        onSuccess: onSuccess ?? this.onSuccess,
      );

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
    );
  }
}
