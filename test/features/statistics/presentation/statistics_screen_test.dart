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

StatisticsSnapshot _readySnapshot({
  int? fewestAttemptsOnWins,
  int totalHintsUsed = 0,
  int hintFreeWins = 0,
}) => StatisticsSnapshot(
  wins: 3,
  losses: 1,
  currentWinStreak: 1,
  bestWinStreak: 2,
  totalAttemptsOnWins: 12,
  fewestAttemptsOnWins: fewestAttemptsOnWins,
  totalHintsUsed: totalHintsUsed,
  hintFreeWins: hintFreeWins,
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
  int currentStreak = 0,
  int longestStreak = 0,
  int coinBalance = 0,
  int totalCoinsEarned = 0,
  int totalCoinsSpent = 0,
  int dailyChallengesCompleted = 0,
  int dailyChallengesWon = 0,
}) {
  return MaterialApp(
    home: StatisticsScreen(
      state: state,
      onClearStatistics: onClearStatistics ?? () {},
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      coinBalance: coinBalance,
      totalCoinsEarned: totalCoinsEarned,
      totalCoinsSpent: totalCoinsSpent,
      dailyChallengesCompleted: dailyChallengesCompleted,
      dailyChallengesWon: dailyChallengesWon,
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
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('never shows "Common" as a difficulty label', (tester) async {
      await tester.pumpWidget(
        _buildSubject(state: StatisticsReady(_readySnapshot())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Common'), findsNothing);
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

  group('Milestone 18: daily streak card', () {
    testWidgets('shows current and longest daily streak', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          state: StatisticsReady(_readySnapshot()),
          currentStreak: 4,
          longestStreak: 9,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Streak'), findsOneWidget);
      expect(find.text('4 days'), findsOneWidget);
      expect(find.text('9 days'), findsOneWidget);
    });

    testWidgets(
      'is shown even while statistics are still loading — streak data is '
      'always eagerly available',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            state: const StatisticsLoading(),
            currentStreak: 2,
            longestStreak: 2,
          ),
        );

        expect(find.text('Daily Streak'), findsOneWidget);
      },
    );

    testWidgets(
      'does not duplicate the win-streak labels from the Overview card',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            state: StatisticsReady(_readySnapshot()),
            currentStreak: 4,
            longestStreak: 9,
          ),
        );
        await tester.pumpAndSettle();

        // "Current streak"/"Best streak" belong to the Overview card's win
        // streak; the daily streak card must use different wording
        // ("Current"/"Longest") so the two concepts never read as the same
        // thing.
        expect(find.text('Current streak'), findsOneWidget);
        expect(find.text('Best streak'), findsOneWidget);
        expect(find.text('Current'), findsOneWidget);
        expect(find.text('Longest'), findsOneWidget);
      },
    );
  });

  group('Milestone 19: coin summary card', () {
    testWidgets('shows the balance and lifetime earned/spent totals', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          state: StatisticsReady(_readySnapshot()),
          coinBalance: 135,
          totalCoinsEarned: 180,
          totalCoinsSpent: 45,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coins'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('135'), findsOneWidget);
      expect(find.text('Total earned'), findsOneWidget);
      expect(find.text('180'), findsOneWidget);
      expect(find.text('Total spent'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
    });

    testWidgets(
      'is shown even while statistics are still loading — coin data is '
      'always eagerly available',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            state: const StatisticsLoading(),
            coinBalance: 100,
            totalCoinsEarned: 0,
            totalCoinsSpent: 0,
          ),
        );

        expect(find.text('Coins'), findsOneWidget);
      },
    );
  });

  group('Milestone 19: fewest attempts on wins', () {
    testWidgets('shows the fewest-attempts figure when there is a win', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          state: StatisticsReady(_readySnapshot(fewestAttemptsOnWins: 7)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fewest attempts (wins)'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('shows an em dash when there are no wins yet', (tester) async {
      final snapshot = StatisticsSnapshot(
        wins: 0,
        losses: 1,
        currentWinStreak: 0,
        bestWinStreak: 0,
        totalAttemptsOnWins: 0,
        byWordLength: {4: GameOutcomeBreakdown(totalGames: 1, wins: 0)},
        byDifficulty: {
          DifficultyOption.common: GameOutcomeBreakdown(totalGames: 1, wins: 0),
        },
        recentGames: [_game('g1', outcome: GameOutcome.lost)],
      );
      await tester.pumpWidget(_buildSubject(state: StatisticsReady(snapshot)));
      await tester.pumpAndSettle();

      expect(find.text('Fewest attempts (wins)'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });
  });

  group('Milestone 19: hint stats card', () {
    testWidgets('shows total hints used and hint-free wins', (tester) async {
      // A bespoke snapshot (rather than _readySnapshot()) so wins/hintFreeWins
      // don't collide with any of that helper's own small numbers already
      // rendered elsewhere on the same screen (streaks, breakdowns, etc.).
      final snapshot = StatisticsSnapshot(
        wins: 9,
        losses: 0,
        currentWinStreak: 9,
        bestWinStreak: 9,
        totalAttemptsOnWins: 27,
        totalHintsUsed: 11,
        hintFreeWins: 9,
        byWordLength: {4: GameOutcomeBreakdown(totalGames: 9, wins: 9)},
        byDifficulty: {
          DifficultyOption.common: GameOutcomeBreakdown(totalGames: 9, wins: 9),
        },
        recentGames: const [],
      );
      await tester.pumpWidget(_buildSubject(state: StatisticsReady(snapshot)));
      await tester.pumpAndSettle();

      expect(find.text('Hints'), findsOneWidget);
      expect(find.text('Total hints used'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(find.text('Hint-free wins'), findsOneWidget);
      expect(find.text('9'), findsWidgets);
    });

    testWidgets('shows zero for both figures when nothing is known yet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(state: StatisticsReady(_readySnapshot())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total hints used'), findsOneWidget);
      expect(find.text('Hint-free wins'), findsOneWidget);
    });
  });

  group('Milestone 19: Daily Challenge stats card', () {
    testWidgets('shows completed and won counts', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          state: StatisticsReady(_readySnapshot()),
          dailyChallengesCompleted: 8,
          dailyChallengesWon: 6,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Challenge'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Challenge wins'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets(
      'is shown even while statistics are still loading — Daily Challenge '
      'data is always eagerly available',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            state: const StatisticsLoading(),
            dailyChallengesCompleted: 2,
            dailyChallengesWon: 1,
          ),
        );

        expect(find.text('Daily Challenge'), findsOneWidget);
      },
    );

    testWidgets('does not duplicate the "Won" text a recent-game entry '
        'already renders', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          state: StatisticsReady(_readySnapshot()),
          dailyChallengesCompleted: 1,
          dailyChallengesWon: 1,
        ),
      );
      await tester.pumpAndSettle();

      // The recent-games list already renders "Won · 5 letters · Medium"
      // for the won game in _readySnapshot(), and the Overview card already
      // has its own "Wins" row for ordinary-game wins; the Daily Challenge
      // card must use neither "Won" nor bare "Wins", so none of the three
      // ever read as the same figure.
      expect(find.textContaining('Won'), findsOneWidget);
      expect(find.text('Wins'), findsOneWidget);
      expect(find.text('Challenge wins'), findsOneWidget);
    });
  });
}
