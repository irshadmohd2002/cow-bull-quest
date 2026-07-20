import 'package:flutter/material.dart';

import '../../../../core/sharing/share_card_renderer.dart';
import '../../../../core/sharing/share_card_service.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_status_colors.dart';
import '../../../../widgets/share_cards/share_streak_button.dart';

/// Shows the daily-play streak: consecutive local calendar days with at
/// least one completed game.
///
/// Deliberately titled "Daily Streak" and labeled "Current"/"Longest" —
/// never "Current streak"/"Best streak" — to stay unambiguous next to
/// [StatisticsSummaryCard]'s own "Current streak"/"Best streak" rows, which
/// track a completely different thing (consecutive *wins*, independent of
/// calendar date). Showing both is intentional, not redundant: win streak
/// and daily-play streak are genuinely different statistics.
class StreakSummaryCard extends StatelessWidget {
  const StreakSummaryCard({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    this.shareCardRenderer = const OffscreenShareCardRenderer(),
    this.shareCardService = const SharePlusShareCardService(),
  });

  final int currentStreak;
  final int longestStreak;

  /// Renders the streak share card to PNG bytes, used by this card's Share
  /// Streak button. Defaults to the real, offscreen-capture implementation;
  /// tests substitute a fake so no real widget-tree capture is ever driven.
  final ShareCardRenderer shareCardRenderer;

  /// Hands the rendered streak share card to the system share sheet.
  /// Defaults to the real, `share_plus`-backed implementation; tests
  /// substitute a fake so no platform channel is ever touched.
  final ShareCardService shareCardService;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final flameColor = currentStreak > 0
        ? (statusColors?.success ?? colorScheme.tertiary)
        : colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: flameColor, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Daily Streak', style: textTheme.titleMedium),
                  ),
                ),
                ShareStreakButton(
                  currentStreak: currentStreak,
                  renderer: shareCardRenderer,
                  service: shareCardService,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _StreakFigure(label: 'Current', days: currentStreak),
                ),
                Expanded(
                  child: _StreakFigure(label: 'Longest', days: longestStreak),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakFigure extends StatelessWidget {
  const _StreakFigure({required this.label, required this.days});

  final String label;
  final int days;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final value = '$days ${days == 1 ? 'day' : 'days'}';
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
