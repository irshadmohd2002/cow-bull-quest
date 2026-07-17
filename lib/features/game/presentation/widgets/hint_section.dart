import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../controllers/game_controller_state.dart';
import '../../models/revealed_hint.dart';

/// Ordinal words for the first several letter positions — every visible
/// game uses a 4-letter secret word (see CLAUDE.md), but this covers
/// `WordRepository`'s full supported range (up to 6 letters) too, falling
/// back to a numeric ordinal beyond that rather than throwing.
const List<String> _ordinals = [
  'first',
  'second',
  'third',
  'fourth',
  'fifth',
  'sixth',
  'seventh',
  'eighth',
  'ninth',
  'tenth',
];

String _ordinalFor(int position) =>
    position < _ordinals.length ? _ordinals[position] : '${position + 1}th';

/// The hint button's exact label for [availability], per Milestone 14's UI
/// rules: "Hint · 20 coins" before a paid hint, "Free Hint" before Hard's
/// first hint, or "No hints remaining" once the limit is reached or no
/// useful hint remains.
String hintButtonLabel(HintAvailability availability) {
  if (!availability.canRequestHint) return 'No hints remaining';
  if (availability.nextHintCost == 0) return 'Free Hint';
  return 'Hint · ${availability.nextHintCost} coins';
}

/// The Hint button and the list of hints already revealed this game.
///
/// Purely presentational and feature-local — [onUseHint] is called with no
/// side effects performed here; the caller (the gameplay screen) owns
/// showing any paid-hint confirmation dialog and actually invoking
/// `GameController.useHint`. [enabled] folds together every reason the
/// button might be disabled (limit reached, no useful hint left,
/// insufficient coin balance, or a hint request already in flight) so this
/// widget never has to know which one applies.
class HintSection extends StatelessWidget {
  const HintSection({
    super.key,
    required this.availability,
    required this.revealedHints,
    required this.coinBalance,
    required this.enabled,
    required this.onUseHint,
  });

  final HintAvailability availability;
  final List<RevealedHint> revealedHints;
  final int coinBalance;

  /// Whether the button should currently be tappable at all.
  final bool enabled;
  final VoidCallback onUseHint;

  /// Whether the sole reason a paid hint is blocked right now is an
  /// insufficient coin balance — shown as extra guidance text beneath an
  /// otherwise-disabled button, distinct from "limit reached".
  bool get _insufficientBalance =>
      availability.canRequestHint &&
      availability.nextHintCost > 0 &&
      coinBalance < availability.nextHintCost;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = hintButtonLabel(availability);

    // Clamped, like GameStatusPanel's supplementary figures: this section
    // sits above the screen's one scrollable region (the guess history), so
    // letting the button/chips grow unbounded at extreme text scale would
    // eventually overflow the layout. Every piece of information here is
    // still fully available at any scale through each element's own
    // Semantics label.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final hint in revealedHints) _HintChip(hint: hint),
          if (revealedHints.isNotEmpty) const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              enabled: enabled,
              label: availability.canRequestHint
                  ? (availability.nextHintCost == 0
                        ? 'Use free hint'
                        : 'Use hint for ${availability.nextHintCost} coins')
                  : 'No hints remaining',
              child: OutlinedButton.icon(
                onPressed: enabled ? onUseHint : null,
                icon: Icon(
                  Icons.lightbulb_outline,
                  color: colorScheme.tertiary,
                ),
                label: Text(label),
              ),
            ),
          ),
          if (_insufficientBalance)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Not enough coins for a hint.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// One revealed hint, shown as a cyan-tinted chip with a lightbulb icon —
/// visually distinct from a guess-history row (which uses the tertiary/
/// secondary badge colors for Bulls/Cows counts, not a full-width
/// container) — so a hinted letter is never mistaken for a submitted guess.
class _HintChip extends StatelessWidget {
  const _HintChip({required this.hint});

  final RevealedHint hint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final letter = hint.letter.toUpperCase();
    final text = 'The ${_ordinalFor(hint.position)} letter is $letter.';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        label: 'Hint: $text',
        excludeSemantics: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb,
                size: 18,
                color: colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
