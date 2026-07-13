import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../models/game_outcome_breakdown.dart';

/// One category's totals within a [StatisticsBreakdownSection]: the human-
/// facing [label] (e.g. `'4 letters'` or `'Easy'`) paired with its
/// [GameOutcomeBreakdown]. Presentation-layer only — the `statistics`
/// feature's models carry no human-facing text of their own.
class BreakdownEntry {
  const BreakdownEntry({required this.label, required this.breakdown});

  final String label;
  final GameOutcomeBreakdown breakdown;
}

/// Shows one titled section of category breakdowns (e.g. by word length or
/// by difficulty), one row per [BreakdownEntry], each row always visible —
/// with `0/0` totals if that category has no completed games yet — so a
/// player can compare all categories side by side.
class StatisticsBreakdownSection extends StatelessWidget {
  const StatisticsBreakdownSection({
    super.key,
    required this.title,
    required this.entries,
  });

  final String title;
  final List<BreakdownEntry> entries;

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
            Semantics(
              header: true,
              child: Text(title, style: textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs / 2,
                ),
                child: Semantics(
                  label:
                      '${entry.label}: ${entry.breakdown.wins} of '
                      '${entry.breakdown.totalGames} won, '
                      '${(entry.breakdown.winRate * 100).round()} percent',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.label, style: textTheme.bodyMedium),
                      Text(
                        '${entry.breakdown.wins} / ${entry.breakdown.totalGames} won '
                        '(${(entry.breakdown.winRate * 100).round()}%)',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
