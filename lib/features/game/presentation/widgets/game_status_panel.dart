import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../controllers/game_controller_state.dart';

/// The at-a-glance status of an in-progress game: word length, difficulty,
/// attempts used, and attempts remaining, plus a supplementary (non-sole)
/// visual progress bar.
///
/// Word length and difficulty are shown as a fixed-height row of two stat
/// chips. Attempts used/remaining are deliberately *not* also duplicated as
/// chips here — [_AttemptSummary] below already states those same figures in
/// full, always-visible text, so a third and fourth chip repeating them
/// would be redundant and, at large text scale inside the chip row's fixed
/// height, prone to clipping (e.g. "Attempts use…"). Keeping the chip row to
/// just two short, unchanging labels means it fits without scrolling on
/// realistic phone widths, even though it remains horizontally scrollable as
/// a safety net for extreme text scale. [_AttemptSummary]'s text scale is
/// capped (not frozen, unlike the chip row above) at 1.3x: this whole panel
/// sits outside the screen's one scrollable region (the guess history), so
/// an unbounded cap here would eventually overflow the layout at extreme
/// text scale — 1.3x still grows meaningfully larger than the base size
/// while keeping that headroom bounded. The single [Semantics] label on the
/// container is the only accessible source for this information — the
/// chips, summary text, and progress bar beneath it are marked
/// [ExcludeSemantics] so a screen reader announces the status once, not
/// once per element.
class GameStatusPanel extends StatelessWidget {
  const GameStatusPanel({
    super.key,
    required this.view,
    required this.difficultyLabel,
  });

  final GameSessionView view;

  /// Human-facing difficulty label, supplied by the caller — this widget
  /// never imports [GameDifficulty] labeling logic itself.
  final String difficultyLabel;

  @override
  Widget build(BuildContext context) {
    final progress = view.maxAttempts == 0
        ? 0.0
        : (view.attemptsUsed / view.maxAttempts).clamp(0.0, 1.0);

    return Semantics(
      container: true,
      label:
          'Word length ${view.wordLength}. Difficulty $difficultyLabel. '
          'Attempts used ${view.attemptsUsed} of ${view.maxAttempts}. '
          'Attempts remaining ${view.attemptsRemaining}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            // Clamped to a fixed text scale and confined to a fixed-height,
            // horizontally-scrolling row: the same figures are always
            // available at full scale via the Semantics label above (and,
            // for word length/difficulty, in the app bar too), so this
            // supplementary visual summary trades its own text scaling for
            // a height that can never grow and squeeze out the guess input.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.0,
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _StatChip(
                      label: 'Word length',
                      value: '${view.wordLength}',
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(label: 'Difficulty', value: difficultyLabel),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ExcludeSemantics(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: _AttemptSummary(
                attemptsUsed: view.attemptsUsed,
                maxAttempts: view.maxAttempts,
                attemptsRemaining: view.attemptsRemaining,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The always-visible, non-scrolling textual equivalent of the progress bar
/// below it: never requires horizontal scrolling (unlike the stat chips
/// above), never relies on color, and wraps rather than overflows at narrow
/// widths since it lives directly in the panel's stretched [Column] rather
/// than a fixed-height/fixed-width container. Its caller clamps how far its
/// text scales (see [GameStatusPanel]'s doc comment) to keep that headroom
/// bounded.
class _AttemptSummary extends StatelessWidget {
  const _AttemptSummary({
    required this.attemptsUsed,
    required this.maxAttempts,
    required this.attemptsRemaining,
  });

  final int attemptsUsed;
  final int maxAttempts;
  final int attemptsRemaining;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.repeat, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '$attemptsUsed of $maxAttempts attempts used · '
            '$attemptsRemaining remaining',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Chip(
      label: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: textTheme.labelMedium),
            TextSpan(
              text: value,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
