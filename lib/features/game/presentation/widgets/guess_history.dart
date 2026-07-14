import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../models/guess.dart';
import 'guess_history_tile.dart';

/// The list of guesses made so far in a session.
///
/// Displayed newest-first: the most recent guess's feedback is what the
/// player needs to see next, and with attempt limits of up to 20 a
/// newest-first list keeps it visible without scrolling.
class GuessHistory extends StatelessWidget {
  const GuessHistory({super.key, required this.guesses});

  /// The guesses made so far, oldest first (as produced by [GameSession]).
  final List<Guess> guesses;

  @override
  Widget build(BuildContext context) {
    if (guesses.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Semantics(
          excludeSemantics: true,
          label: 'No guesses yet. Make your first guess.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_edu_outlined,
                size: 40,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No guesses yet. Make your first guess!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final newestFirst = guesses.reversed.toList();
    return ListView.separated(
      itemCount: newestFirst.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) =>
          GuessHistoryTile(guess: newestFirst[index]),
    );
  }
}
