import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_status_colors.dart';

/// Shows lifetime Daily Challenge totals: how many calendar dates have an
/// official result (won or lost) recorded, and how many of those were won.
///
/// Sourced from `DailyChallengeController.completedCount`/`wonCount` (see
/// `CowBullApp._openStatistics`) rather than [StatisticsSnapshot] — a Daily
/// Challenge completion is never folded into the general win/loss
/// statistics a normal game feeds (see `CowBullApp._recordDailyChallengeCompletion`),
/// so this is genuinely separate data, not a duplicate of anything the
/// Overview card already shows. Labeled "Challenge wins" — never the bare
/// "Wins" — precisely so it never reads as a duplicate of the Overview
/// card's own "Wins" figure (ordinary-game wins), which tracks a completely
/// different count; mirrors [StreakSummaryCard]'s own "Current"/"Longest" vs
/// "Current streak"/"Best streak" disambiguation for the same reason.
class DailyChallengeStatsCard extends StatelessWidget {
  const DailyChallengeStatsCard({
    super.key,
    required this.completed,
    required this.won,
  });

  /// The number of calendar dates with an official Daily Challenge result.
  final int completed;

  /// The number of those official results that were won.
  final int won;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final accent = statusColors?.success ?? colorScheme.tertiary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available, color: accent, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Daily Challenge',
                      style: textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _DailyChallengeFigure(
                    label: 'Completed',
                    value: '$completed',
                  ),
                ),
                Expanded(
                  child: _DailyChallengeFigure(
                    label: 'Challenge wins',
                    value: '$won',
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

class _DailyChallengeFigure extends StatelessWidget {
  const _DailyChallengeFigure({required this.label, required this.value});

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
