import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'cow_head_icon.dart';

/// Which of the two Bulls/Cows counts a [GuessResultBadge] represents.
enum GuessResultBadgeType { bull, cow }

/// A compact, single-line badge for one Bulls/Cows total: an icon, the
/// correctly-pluralized noun ("Bull"/"Bulls" or "Cow"/"Cows"), and the
/// count — e.g. "🎯 Bulls 2", "🐮 Cow 1".
///
/// Shared by the active game's guess history and any Rules/onboarding
/// example that shows the same aggregate-count concept (see CLAUDE.md —
/// presentation-only widgets used by 2+ features live under `widgets/`).
/// [icon] and [accentColor] default to this badge's [type] (a target icon
/// in cyan for Bull, [CowHeadIcon] in gold for Cow) but can be overridden by
/// a caller that needs different styling; count and label are always shown
/// as text, and the icon differs by shape (not just color) between the two
/// types, so meaning is never conveyed by color alone.
class GuessResultBadge extends StatelessWidget {
  const GuessResultBadge({
    super.key,
    required this.type,
    required this.count,
    this.icon,
    this.accentColor,
  });

  /// Whether this badge shows the Bull or Cow total.
  final GuessResultBadgeType type;

  /// The count shown, and the deciding factor for singular vs. plural.
  final int count;

  /// Overrides the default per-[type] icon.
  final Widget? icon;

  /// Overrides the default per-[type] accent (icon color, border, and the
  /// tint used to derive the badge's background).
  final Color? accentColor;

  // Mirrors AppTheme's own gold constants rather than reusing
  // AppStatusColors.success: that role is reserved for premium/reward
  // moments (see its class doc) and would lose that special meaning if
  // spent on a badge shown on every guess.
  static const Color _cowAccentLight = Color(0xFFB98525);
  static const Color _cowAccentDark = Color(0xFFD6A84B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBull = type == GuessResultBadgeType.bull;

    final accent =
        accentColor ??
        (isBull
            ? colorScheme.tertiary
            : (theme.brightness == Brightness.dark
                  ? _cowAccentDark
                  : _cowAccentLight));
    final background = Color.lerp(accent, colorScheme.surface, 0.82)!;
    final foreground = colorScheme.onSurface;

    final noun = isBull ? 'Bull' : 'Cow';
    final label = count == 1 ? noun : '${noun}s';
    final resolvedIcon =
        icon ??
        (isBull
            ? Icon(Icons.gps_fixed_rounded, size: 15, color: accent)
            : CowHeadIcon(size: 15, color: accent));

    return Semantics(
      label: '$count $label',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              resolvedIcon,
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$label $count',
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
