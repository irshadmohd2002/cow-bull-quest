import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_status_colors.dart';

/// A compact, accessible display of the player's current coin balance.
///
/// Used on both the Home and Game screens (see CLAUDE.md — shared,
/// presentation-only widgets used by 2+ features live under `widgets/`) so
/// the same coin representation reads identically everywhere it appears.
/// Purely presentational: it receives [balance] as a plain `int` rather
/// than depending on `CoinWallet` itself, the same pattern
/// `GameStatusPanel` uses for `difficultyLabel`. Gold is used here — via
/// [AppStatusColors.success] — for the coin icon only, consistent with this
/// app's "gold sparingly, for reward moments" rule; the balance text itself
/// uses the theme's normal text color, never gold, so it stays legible at
/// every text scale and never conveys meaning by color alone (the coin
/// count is always plain text).
///
/// The displayed number itself updates the instant [balance] changes — it
/// is always the same value the caller passed in, never a separately
/// tracked "fake" balance — but a balance decrease (e.g. spending on a
/// hint) also plays a brief, restrained scale pulse plus a transient
/// "-N" label that fades out beside it, so a coin spend reads as a
/// deliberate, visible event rather than a silent number change.
class CoinBalanceBadge extends StatefulWidget {
  const CoinBalanceBadge({super.key, required this.balance});

  /// The current coin balance to display.
  final int balance;

  @override
  State<CoinBalanceBadge> createState() => _CoinBalanceBadgeState();
}

class _CoinBalanceBadgeState extends State<CoinBalanceBadge> {
  /// The change in balance that produced the current [_changeCount], or `0`
  /// on the very first build (no pulse/label then — there is nothing to
  /// react to yet).
  int _delta = 0;

  /// Bumped every time [widget.balance] actually changes. Used as a
  /// [ValueKey] for the pulse/label [TweenAnimationBuilder]s below, so each
  /// genuine change gets a fresh animation from its starting value rather
  /// than replaying or stacking on top of an in-flight one.
  int _changeCount = 0;

  @override
  void didUpdateWidget(CoinBalanceBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.balance != oldWidget.balance) {
      _delta = widget.balance - oldWidget.balance;
      _changeCount++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final coinColor = statusColors?.success ?? colorScheme.tertiary;
    final pulseDuration = AppMotion.durationFor(context, AppMotion.emphasis);
    final spent = _delta < 0;

    return Semantics(
      label: '${widget.balance} coins',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(_changeCount),
            tween: Tween(begin: spent ? 1.12 : 1.0, end: 1.0),
            duration: pulseDuration,
            curve: Curves.easeOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs / 2,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on, size: 18, color: coinColor),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${widget.balance}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (spent)
            Positioned(
              top: -10,
              right: 0,
              child: ExcludeSemantics(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('delta-$_changeCount'),
                  tween: Tween(begin: 1.0, end: 0.0),
                  duration: pulseDuration,
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: Text(
                    '$_delta',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
