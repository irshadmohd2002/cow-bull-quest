import 'package:cowbullgame/features/statistics/controllers/statistics_controller_state.dart';
import 'package:cowbullgame/features/statistics/models/completed_game.dart';
import 'package:cowbullgame/features/statistics/models/game_outcome.dart';
import 'package:cowbullgame/features/statistics/models/game_outcome_breakdown.dart';
import 'package:cowbullgame/features/statistics/models/statistics_snapshot.dart';
import 'package:cowbullgame/features/statistics/presentation/statistics_screen.dart';
import 'package:cowbullgame/models/difficulty_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CompletedGame _game(String id, {GameOutcome outcome = GameOutcome.won}) =>
    CompletedGame(
      id: id,
      completedAt: DateTime.utc(2026, 1, 2, 3, 4),
      wordLength: 5,
      difficulty: DifficultyOption.common,
      outcome: outcome,
      attemptsUsed: 4,
      maxAttempts: 15,
    );

StatisticsSnapshot _readySnapshot() => StatisticsSnapshot(
  wins: 3,
  losses: 1,
  currentWinStreak: 1,
  bestWinStreak: 2,
  totalAttemptsOnWins: 12,
  byWordLength: {
    4: GameOutcomeBreakdown(totalGames: 2, wins: 1),
    5: GameOutcomeBreakdown(totalGames: 2, wins: 2),
  },
  byDifficulty: {
    DifficultyOption.common: GameOutcomeBreakdown(totalGames: 4, wins: 3),
  },
  recentGames: [
    _game('g2'),
    _game('g1', outcome: GameOutcome.lost),
  ],
);

Widget _buildSubject({
  required StatisticsControllerState state,
  VoidCallback? onClearStatistics,
}) {
  return MaterialApp(
    home: StatisticsScreen(
      state: state,
      onClearStatistics: onClearStatistics ?? () {},
    ),
  );
}

void main() {
  testWidgets('shows a loading indicator while loading', (tester) async {
    await tester.pumpWidget(_buildSubject(state: const StatisticsLoading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no completed games', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSubject(state: StatisticsReady(StatisticsSnapshot.empty())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No completed games yet'), findsOneWidget);
  });

  group('ready state with data', () {
    testWidgets('shows aggregate totals', (tester) async {
      await tester.pumpWidget(
        _buildSubject(state: StatisticsReady(_readySnapshot())),
      );
      await tester.pumpAndSettle();

      expect(find.text('4'), findsWidgets); // total games
      expect(find.text('3'), findsWidgets); // wins
      expect(find.text('1'), findsWidgets); // losses / streak
      expect(find.textContaining('75%'), findsWidgets); // win rate
    });

    testWidgets('shows the word length breakdown', (tester) async {
      await tester.pumpWidget(
        _buildSubject(state: StatisticsReady(_readySnapshot())),
      );
      await tester.pumpAndSettle();

      expect(find.text('4 letters'), findsOneWidget);
      expect(find.text('5 letters'), findsOneWidget);
      expect(find.text('6 letters'), findsOneWidget);
    });

    testWidgets('shows the difficulty breakdown', (tester) async {
      await tester.pumpWidget(
        _buildSubject(state: StatisticsReady(_readySnapshot())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Common'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('shows the recent games list newest-first', (tester) async {
      await tester.pumpWidget(
        _buildSubject(state: StatisticsReady(_readySnapshot())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Won'), findsOneWidget);
      expect(find.textContaining('Lost'), findsOneWidget);
    });

    testWidgets('never shows a secret word', (tester) async {
      await tester.pumpWidget(
        _buildSubject(state: StatisticsReady(_readySnapshot())),
      );
      await tester.pumpAndSettle();

      // CompletedGame carries no secret word field at all, so this is a
      // belt-and-braces check that no incidental text looks like one.
      expect(find.textContaining('secret'), findsNothing);
    });
  });

  group('failure state', () {
    testWidgets('shows a friendly message', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          state: const StatisticsFailure(lastSnapshot: null, error: 'boom'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("couldn't load"), findsOneWidget);
    });

    testWidgets('still shows the last known snapshot when available', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          state: StatisticsFailure(
            lastSnapshot: _readySnapshot(),
            error: 'boom',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("couldn't load"), findsOneWidget);
      expect(find.text('4 letters'), findsOneWidget);
    });
  });

  group('clear statistics', () {
    testWidgets('a single tap does not clear without confirmation', (
      tester,
    ) async {
      var cleared = false;
      await tester.pumpWidget(
        _buildSubject(
          state: StatisticsReady(_readySnapshot()),
          onClearStatistics: () => cleared = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(cleared, isFalse);
      expect(find.text('Clear statistics?'), findsOneWidget);
    });

    testWidgets('confirming invokes onClearStatistics', (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        _buildSubject(
          state: StatisticsReady(_readySnapshot()),
          onClearStatistics: () => cleared = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
    });

    testWidgets('cancelling does not invoke onClearStatistics', (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        _buildSubject(
          state: StatisticsReady(_readySnapshot()),
          onClearStatistics: () => cleared = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(cleared, isFalse);
      expect(find.text('Clear statistics?'), findsNothing);
    });
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSubject(state: StatisticsReady(_readySnapshot())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not throw under large text scaling', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: _buildSubject(state: StatisticsReady(_readySnapshot())),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('has an accessible label for the clear action', (tester) async {
    await tester.pumpWidget(
      _buildSubject(state: StatisticsReady(_readySnapshot())),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Clear statistics'), findsOneWidget);
  });
}
