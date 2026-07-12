import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../models/guess.dart';

/// One row of guess history: the turn number, the guessed word, and its
/// scored bulls/cows — always as visible text, never conveyed by color
/// alone. Bulls and cows each get a distinct (non-color-only) icon so the
/// two counts stay visually distinguishable even for a color-blind reader.
class GuessHistoryTile extends StatelessWidget {
  const GuessHistoryTile({super.key, required this.guess});

  final Guess guess;

  @override
  Widget build(BuildContext context) {
    final bulls = guess.result.bulls;
    final cows = guess.result.cows;

    return Semantics(
      excludeSemantics: true,
      label:
          'Guess ${guess.turnNumber}: ${guess.word}, '
          '$bulls ${bulls == 1 ? 'bull' : 'bulls'}, '
          '$cows ${cows == 1 ? 'cow' : 'cows'}',
      child: ListTile(
        leading: CircleAvatar(child: Text('${guess.turnNumber}')),
        title: Text(
          guess.word.toUpperCase(),
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScoreBadge(icon: Icons.gps_fixed, label: 'Bulls', value: bulls),
            const SizedBox(width: AppSpacing.sm),
            _ScoreBadge(icon: Icons.sync_alt, label: 'Cows', value: cows),
          ],
        ),
      ),
    );
  }
}

/// A small text-plus-icon badge for one score (bulls or cows). The icon is
/// purely decorative reinforcement — [label] and [value] are always shown as
/// text, so the score is never conveyed by icon or color alone.
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
