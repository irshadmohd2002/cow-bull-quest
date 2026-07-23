import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../../../widgets/guess_result_badge.dart';
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

    // A plain Row, not a Material ListTile: ListTile budgets its trailing
    // slot's size (both width and height) against its own single-line
    // content assumptions, which two badges can exceed at large text-scale
    // factors (a real, previously-hit RenderFlex overflow), while a wide
    // single-line trailing Row can exceed ListTile's separate hard rule
    // that trailing must never consume the tile's entire width on narrow
    // screens (also previously hit). A Row here simply sizes itself to its
    // children's natural size with no hidden budget, so it stays
    // overflow-safe at both extremes.
    return Semantics(
      excludeSemantics: true,
      label:
          'Guess ${guess.turnNumber}: ${guess.word}, '
          '$bulls ${bulls == 1 ? 'bull' : 'bulls'}, '
          '$cows ${cows == 1 ? 'cow' : 'cows'}',
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: Text('${guess.turnNumber}'),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  guess.word.toUpperCase(),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Each badge is independently Flexible (rather than the Row
              // itself being one Flexible child) so a badge shrinks via its
              // own internal FittedBox only as far as it individually needs
              // to — the two badges never fight each other for the same
              // shrink budget.
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: GuessResultBadge(
                        type: GuessResultBadgeType.bull,
                        count: bulls,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: GuessResultBadge(
                        type: GuessResultBadgeType.cow,
                        count: cows,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
