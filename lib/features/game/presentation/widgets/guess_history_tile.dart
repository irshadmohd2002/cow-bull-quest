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

    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      excludeSemantics: true,
      label:
          'Guess ${guess.turnNumber}: ${guess.word}, '
          '$bulls ${bulls == 1 ? 'bull' : 'bulls'}, '
          '$cows ${cows == 1 ? 'cow' : 'cows'}',
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text('${guess.turnNumber}'),
          ),
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
              _ScoreBadge(
                icon: Icons.gps_fixed,
                label: 'Bulls',
                value: bulls,
                background: colorScheme.tertiaryContainer,
                foreground: colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              _ScoreBadge(
                icon: Icons.sync_alt,
                label: 'Cows',
                value: cows,
                background: colorScheme.secondaryContainer,
                foreground: colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small text-plus-icon badge for one score (bulls or cows). The icon is
/// purely decorative reinforcement — [label] and [value] are always shown as
/// text, so the score is never conveyed by icon or color alone. [background]/
/// [foreground] give bulls and cows visually distinct, accessible colors
/// (never relying on the icon or text alone to tell them apart).
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$label: $value',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
