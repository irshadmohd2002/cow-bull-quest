import 'package:flutter/material.dart';

import '../../../../models/difficulty_selection.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_status_colors.dart';
import '../../models/completed_game.dart';
import '../../models/game_outcome.dart';

/// Concise, human-facing label for [option]. Presentation-layer concern —
/// [DifficultyOption] itself carries no human-facing text.
String _difficultyLabel(DifficultyOption option) => switch (option) {
  DifficultyOption.easy => 'Easy',
  DifficultyOption.common => 'Medium',
  DifficultyOption.hard => 'Hard',
};

String _outcomeLabel(GameOutcome outcome) => switch (outcome) {
  GameOutcome.won => 'Won',
  GameOutcome.lost => 'Lost',
};

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Formats [dateTime] for display only — this is presentation text, never
/// re-parsed or persisted from here.
String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

/// Shows the bounded, newest-first list of recently completed games from a
/// [CompletedGame] list.
///
/// Deliberately has no access to a secret word or guess history —
/// [CompletedGame] never carries either — so this list can never leak one.
class RecentGamesList extends StatelessWidget {
  const RecentGamesList({super.key, required this.games});

  final List<CompletedGame> games;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final wonColor = statusColors?.success ?? colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('Recent games', style: textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (games.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  'No games yet.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final game in games)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Semantics(
                    label:
                        '${_outcomeLabel(game.outcome)}, ${game.wordLength} '
                        'letters, ${_difficultyLabel(game.difficulty)}, '
                        '${game.attemptsUsed} of ${game.maxAttempts} '
                        'attempts, ${_formatDateTime(game.completedAt)}',
                    excludeSemantics: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          game.outcome == GameOutcome.won
                              ? Icons.emoji_events
                              : Icons.flag,
                          size: 18,
                          color: game.outcome == GameOutcome.won
                              ? wonColor
                              : colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_outcomeLabel(game.outcome)} · '
                                '${game.wordLength} letters · '
                                '${_difficultyLabel(game.difficulty)}',
                              ),
                              Text(
                                'Attempts: ${game.attemptsUsed} / '
                                '${game.maxAttempts} · '
                                '${_formatDateTime(game.completedAt)}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
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
