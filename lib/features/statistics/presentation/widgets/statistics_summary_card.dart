import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../models/statistics_snapshot.dart';

/// One label/value row within [StatisticsSummaryCard].
///
/// A [Column] (label above value) rather than a single [Row], so a long
/// label at large text-scale factors wraps onto its own lines instead of
/// squeezing the value — every number stays fully readable at 3x text
/// scaling.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value',
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

/// Shows the aggregate numbers from a [StatisticsSnapshot]: total games,
/// wins, losses, win rate, current streak, best streak, and average
/// attempts on wins.
///
/// Every number is communicated as text — never by color alone — so it
/// reads identically to a screen-reader user and a colorblind player.
class StatisticsSummaryCard extends StatelessWidget {
  const StatisticsSummaryCard({super.key, required this.snapshot});

  final StatisticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final averageAttempts = snapshot.averageAttemptsOnWins;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Overview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _SummaryRow(label: 'Total games', value: '${snapshot.totalGames}'),
            _SummaryRow(label: 'Wins', value: '${snapshot.wins}'),
            _SummaryRow(label: 'Losses', value: '${snapshot.losses}'),
            _SummaryRow(
              label: 'Win rate',
              value: '${(snapshot.winRate * 100).round()}%',
            ),
            _SummaryRow(
              label: 'Current streak',
              value: '${snapshot.currentWinStreak}',
            ),
            _SummaryRow(
              label: 'Best streak',
              value: '${snapshot.bestWinStreak}',
            ),
            _SummaryRow(
              label: 'Average attempts (wins)',
              value: averageAttempts == null
                  ? '—'
                  : averageAttempts.toStringAsFixed(1),
            ),
          ],
        ),
      ),
    );
  }
}
