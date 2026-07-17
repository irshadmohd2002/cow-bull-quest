import 'package:flutter/material.dart';

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
class CoinBalanceBadge extends StatelessWidget {
  const CoinBalanceBadge({super.key, required this.balance});

  /// The current coin balance to display.
  final int balance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final coinColor = statusColors?.success ?? colorScheme.tertiary;

    return Semantics(
      label: '$balance coins',
      excludeSemantics: true,
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
              '$balance',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
