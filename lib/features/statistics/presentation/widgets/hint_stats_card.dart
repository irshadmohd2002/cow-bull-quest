import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../models/statistics_snapshot.dart';

/// Shows Milestone 19's hint-usage aggregates: the lifetime total number of
/// hints used across every completed game, and how many wins used no hint
/// at all.
///
/// [StatisticsSnapshot.totalHintsUsed]/[StatisticsSnapshot.hintFreeWins] both
/// deliberately exclude any game whose hint usage is unknown (a record from
/// before Milestone 19) — see the snapshot's own doc — so a fresh migration
/// never overstates hint-free wins the player didn't actually confirm.
class HintStatsCard extends StatelessWidget {
  const HintStatsCard({super.key, required this.snapshot});

  final StatisticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: colorScheme.tertiary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Hints', style: textTheme.titleMedium),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _HintFigure(
                    label: 'Total hints used',
                    value: '${snapshot.totalHintsUsed}',
                  ),
                ),
                Expanded(
                  child: _HintFigure(
                    label: 'Hint-free wins',
                    value: '${snapshot.hintFreeWins}',
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

class _HintFigure extends StatelessWidget {
  const _HintFigure({required this.label, required this.value});

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
