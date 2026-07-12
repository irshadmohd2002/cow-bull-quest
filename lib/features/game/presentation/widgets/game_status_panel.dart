import 'package:flutter/material.dart';

import '../../controllers/game_controller_state.dart';

/// The at-a-glance status of an in-progress game: word length, attempts
/// used, and attempts remaining.
///
/// Uses [Wrap] rather than a fixed [Row] so the three stats reflow onto
/// additional lines instead of overflowing under large text scaling or on
/// narrow screens.
class GameStatusPanel extends StatelessWidget {
  const GameStatusPanel({super.key, required this.view});

  final GameSessionView view;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Word length ${view.wordLength}. '
          'Attempts used ${view.attemptsUsed} of ${view.maxAttempts}. '
          'Attempts remaining ${view.attemptsRemaining}.',
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _StatChip(label: 'Word length', value: '${view.wordLength}'),
          _StatChip(
            label: 'Attempts used',
            value: '${view.attemptsUsed} / ${view.maxAttempts}',
          ),
          _StatChip(
            label: 'Attempts remaining',
            value: '${view.attemptsRemaining}',
          ),
        ],
      ),
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
    return ExcludeSemantics(
      child: Chip(
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
      ),
    );
  }
}
