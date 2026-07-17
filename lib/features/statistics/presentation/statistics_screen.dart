import 'package:flutter/material.dart';

import '../../../models/difficulty_selection.dart';
import '../../../theme/app_spacing.dart';
import '../controllers/statistics_controller_state.dart';
import '../models/completed_game.dart';
import '../models/game_outcome_breakdown.dart';
import '../models/statistics_snapshot.dart';
import 'widgets/recent_games_list.dart';
import 'widgets/statistics_breakdown_section.dart';
import 'widgets/statistics_summary_card.dart';
import 'widgets/streak_summary_card.dart';

/// The secret-word lengths shown in the by-length breakdown, in display
/// order. Kept local to presentation, like [_difficultyLabel] below — the
/// `statistics` feature never imports the `game` feature's own supported-
/// lengths constant.
const List<int> _wordLengthBreakdownOrder = [4, 5, 6];

/// Difficulty display order for the by-difficulty breakdown, easiest first.
const List<DifficultyOption> _difficultyBreakdownOrder = [
  DifficultyOption.easy,
  DifficultyOption.common,
  DifficultyOption.hard,
];

String _difficultyLabel(DifficultyOption option) => switch (option) {
  DifficultyOption.easy => 'Easy',
  DifficultyOption.common => 'Medium',
  DifficultyOption.hard => 'Hard',
};

/// Shows a confirmation dialog before clearing statistics, so the
/// destructive action can never be triggered by a single accidental tap.
Future<void> _confirmClear(
  BuildContext context,
  VoidCallback onConfirmed,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Clear statistics?'),
      content: const Text(
        'This permanently deletes your win/loss history and recent games. '
        'Your theme setting is not affected. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) onConfirmed();
}

/// Shows completed-game statistics: aggregate totals, streaks, breakdowns
/// by word length and difficulty, and a bounded recent-games list.
///
/// Purely presentational and feature-local — it receives [state] and
/// [onClearStatistics] from the app-level composition root, which owns the
/// `StatisticsController` this reflects, and never imports the `game`
/// feature: every completed-game fact it can show ([CompletedGame]) already
/// carries no secret word or guess content.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({
    super.key,
    required this.state,
    required this.onClearStatistics,
    required this.currentStreak,
    required this.longestStreak,
  });

  /// The current statistics lifecycle state to render.
  final StatisticsControllerState state;

  /// Called after the player confirms the clear-statistics dialog.
  final VoidCallback onClearStatistics;

  /// The player's current/longest daily-play streak — always available
  /// (independent of [state]'s own load lifecycle, since streak data is
  /// loaded eagerly at app startup), so it is shown even while [state] is
  /// still [StatisticsLoading] or has failed to load.
  final int currentStreak;
  final int longestStreak;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear statistics',
            onPressed: () => _confirmClear(context, onClearStatistics),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreakSummaryCard(
                currentStreak: currentStreak,
                longestStreak: longestStreak,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildBody(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, StatisticsControllerState state) {
    return switch (state) {
      StatisticsLoading() => const _LoadingView(),
      StatisticsReady(:final snapshot) => _StatisticsContent(
        snapshot: snapshot,
      ),
      StatisticsFailure(:final lastSnapshot, :final error) => _FailureView(
        error: error,
        lastSnapshot: lastSnapshot,
      ),
    };
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Semantics(
          label: 'Loading statistics.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Loading statistics...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.error, required this.lastSnapshot});

  final Object error;
  final StatisticsSnapshot? lastSnapshot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lastSnapshot = this.lastSnapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label:
              "We couldn't load your statistics right now. "
              'Go back and reopen Statistics to try again.',
          child: ExcludeSemantics(
            child: Card(
              color: colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        "We couldn't load your statistics right now. Go "
                        'back and reopen Statistics to try again.',
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (lastSnapshot != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _StatisticsContent(snapshot: lastSnapshot),
        ],
      ],
    );
  }
}

class _EmptyStatisticsView extends StatelessWidget {
  const _EmptyStatisticsView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Semantics(
          label:
              'No completed games yet. Play a game to see your statistics '
              'here.',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No completed games yet.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Play a game to see your statistics here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({required this.snapshot});

  final StatisticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.totalGames == 0) {
      return const _EmptyStatisticsView();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatisticsSummaryCard(snapshot: snapshot),
        const SizedBox(height: AppSpacing.md),
        StatisticsBreakdownSection(
          title: 'By word length',
          entries: [
            for (final wordLength in _wordLengthBreakdownOrder)
              BreakdownEntry(
                label: '$wordLength letters',
                breakdown:
                    snapshot.byWordLength[wordLength] ??
                    GameOutcomeBreakdown.empty,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        StatisticsBreakdownSection(
          title: 'By difficulty',
          entries: [
            for (final difficulty in _difficultyBreakdownOrder)
              BreakdownEntry(
                label: _difficultyLabel(difficulty),
                breakdown:
                    snapshot.byDifficulty[difficulty] ??
                    GameOutcomeBreakdown.empty,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        RecentGamesList(games: snapshot.recentGames),
      ],
    );
  }
}
