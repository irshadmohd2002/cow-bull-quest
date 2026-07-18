import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_status_colors.dart';

/// Shows the player's coin economy: the current balance, and the lifetime
/// totals of every coin ever earned (Milestone 19's completed-game rewards)
/// or spent (hint purchases).
///
/// Mirrors [StreakSummaryCard]'s layout and role: like the daily streak,
/// coin totals are always available independently of the statistics
/// snapshot's own load lifecycle (`CoinWallet` is loaded eagerly at app
/// startup), so this card is shown even while completed-game statistics are
/// still loading or have failed to load.
class CoinSummaryCard extends StatelessWidget {
  const CoinSummaryCard({
    super.key,
    required this.coinBalance,
    required this.totalCoinsEarned,
    required this.totalCoinsSpent,
  });

  /// The current, spendable coin balance.
  final int coinBalance;

  /// The lifetime total of every coin ever earned from a completed-game
  /// reward. Never reduced by spending.
  final int totalCoinsEarned;

  /// The lifetime total of every coin ever spent on a hint. Never reduced
  /// by earning.
  final int totalCoinsSpent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final coinAccent = statusColors?.success ?? colorScheme.tertiary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.paid, color: coinAccent, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Semantics(
                  header: true,
                  child: Text('Coins', style: textTheme.titleMedium),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _CoinFigure(label: 'Balance', coins: coinBalance),
                ),
                Expanded(
                  child: _CoinFigure(
                    label: 'Total earned',
                    coins: totalCoinsEarned,
                  ),
                ),
                Expanded(
                  child: _CoinFigure(
                    label: 'Total spent',
                    coins: totalCoinsSpent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinFigure extends StatelessWidget {
  const _CoinFigure({required this.label, required this.coins});

  final String label;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final value = '$coins';
    return Semantics(
      label: '$label: $value coins',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
