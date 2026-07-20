import 'package:flutter/material.dart';

import '../../../core/sharing/share_card_renderer.dart';
import '../../../core/sharing/share_card_service.dart';
import '../../../models/difficulty_selection.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_status_colors.dart';
import '../../../widgets/coin_balance_badge.dart';
import '../../../widgets/share_cards/share_streak_button.dart';
import '../models/daily_challenge_card_status.dart';

/// Concise, human-facing label for [option]. Presentation-layer concern —
/// [DifficultyOption] itself carries no human-facing text. The internal
/// [DifficultyOption.common] value keeps its enum name to avoid an
/// unnecessary migration of stored statistics; only its displayed label
/// changed from "Common" to "Medium".
String _difficultyLabel(DifficultyOption option) => switch (option) {
  DifficultyOption.easy => 'Easy',
  DifficultyOption.common => 'Medium',
  DifficultyOption.hard => 'Hard',
};

/// Concise, human-facing description of [option], shown alongside the
/// label so a player can choose without leaving Home. Mirrors the fuller
/// explanation on the Rules screen.
String _difficultyDescription(DifficultyOption option) => switch (option) {
  DifficultyOption.easy => 'Familiar, high-frequency words.',
  DifficultyOption.common => 'Broader everyday vocabulary.',
  DifficultyOption.hard => 'Less frequent, trickier words.',
};

/// The Material icon representing [option], distinct for the selected vs.
/// unselected state (a filled glyph when selected, an outlined one
/// otherwise) — one of several non-color cues (alongside the segment's own
/// selected styling and this screen's [_DifficultyDescriptionRow]) that make
/// the current selection obvious without relying on color alone.
IconData _difficultyIcon(DifficultyOption option, {required bool selected}) =>
    switch (option) {
      DifficultyOption.easy => selected ? Icons.eco : Icons.eco_outlined,
      DifficultyOption.common =>
        selected ? Icons.track_changes : Icons.track_changes_outlined,
      DifficultyOption.hard =>
        selected
            ? Icons.local_fire_department
            : Icons.local_fire_department_outlined,
    };

/// The app's entry screen: a brief explanation of the game, a choice of
/// difficulty (Easy, Medium, or Hard), and entry points to starting a game,
/// How to Play, and Settings.
///
/// Every game — regardless of difficulty — always uses a 4-letter secret
/// word and allows 10 attempts (see Milestone 12); difficulty only changes
/// which word pool the secret word is drawn from. Purely presentational and
/// feature-local — it owns only the selected difficulty (the shared,
/// feature-neutral [DifficultyOption]) as local state, and never imports
/// anything from the `game`, `rules`, or `settings` features (no
/// `GameConfig`, no `GameDifficulty`, no repository, no engine, no
/// controller, no other feature's screen). All three actions are handed off
/// entirely to [onStartGame], [onOpenRules], and [onOpenSettings], which the
/// app-level composition root supplies; that composition root is the one
/// place that turns the chosen difficulty into a `GameConfig` via
/// `GameConfig.forSelection` (always with `GameConfig.visibleWordLength`)
/// and owns navigation to the other screens.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onStartGame,
    required this.onOpenRules,
    required this.onOpenSettings,
    required this.onOpenStatistics,
    required this.coinBalance,
    required this.currentStreak,
    required this.longestStreak,
    required this.dailyChallengeStatus,
    required this.dailyChallengeDateLabel,
    required this.onOpenDailyChallenge,
    this.onDifficultySelected,
    this.shareCardRenderer = const OffscreenShareCardRenderer(),
    this.shareCardService = const SharePlusShareCardService(),
  });

  /// Called with the chosen difficulty when the player starts a game. Every
  /// game always uses a 4-letter secret word and 10 attempts, so no word
  /// length is passed here.
  final void Function(DifficultyOption difficulty) onStartGame;

  /// Called when the player wants to see the How to Play screen.
  final VoidCallback onOpenRules;

  /// Called when the player wants to see the Settings screen.
  final VoidCallback onOpenSettings;

  /// Called when the player wants to see the Statistics screen. Neutral by
  /// design — this screen never imports the `statistics` feature itself;
  /// the app-level composition root owns navigating there and supplying it
  /// with a `StatisticsController`.
  final VoidCallback onOpenStatistics;

  /// The player's current coin balance, shown compactly in the app bar.
  /// Passed as a plain `int` — like every other value this screen receives
  /// — rather than a `CoinWallet` reference, so this screen stays purely
  /// presentational; the app-level composition root owns listening to the
  /// wallet and rebuilding this screen when it changes.
  final int coinBalance;

  /// The player's current daily-play streak, in days. `0` for a brand-new
  /// player or one whose streak has lapsed — rendered with friendly,
  /// non-punitive copy (see [_StreakSummaryRow]), never as an error or
  /// warning state.
  final int currentStreak;

  /// The longest streak ever reached, shown less prominently alongside
  /// [currentStreak].
  final int longestStreak;

  /// Today's Daily Challenge completion state, for the Daily Challenge
  /// card.
  final DailyChallengeCardStatus dailyChallengeStatus;

  /// A short, human-readable label for today's date (e.g. "18 July 2026"),
  /// shown on the Daily Challenge card. Formatted by the app-level
  /// composition root so this screen never needs its own date-formatting
  /// logic or an `intl` dependency.
  final String dailyChallengeDateLabel;

  /// Called when the player taps the Daily Challenge card.
  final VoidCallback onOpenDailyChallenge;

  /// Called with the newly-chosen difficulty whenever the player picks a
  /// different segment, or `null` to report nothing. Deliberately generic —
  /// this screen never imports anything audio/haptic-related itself; the
  /// app-level composition root supplies the real behavior (see `app.dart`).
  final ValueChanged<DifficultyOption>? onDifficultySelected;

  /// Renders the streak share card to PNG bytes, used by the streak row's
  /// Share Streak button. Defaults to the real, offscreen-capture
  /// implementation; tests substitute a fake so no real widget-tree capture
  /// is ever driven.
  final ShareCardRenderer shareCardRenderer;

  /// Hands the rendered streak share card to the system share sheet.
  /// Defaults to the real, `share_plus`-backed implementation; tests
  /// substitute a fake so no platform channel is ever touched.
  final ShareCardService shareCardService;

  /// The difficulty preselected when Home first appears. `common` — the
  /// broadest, middle-of-the-road pool — is the least surprising default
  /// for a first-time player, neither the easiest nor the hardest option.
  static const DifficultyOption _defaultDifficulty = DifficultyOption.common;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DifficultyOption _selectedDifficulty = HomeScreen._defaultDifficulty;

  void _handleStart() {
    widget.onStartGame(_selectedDifficulty);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // Tightens segment padding on narrow devices (e.g. 320-wide) so the
    // FittedBox-scaled labels in [_SegmentLabel] have as much room as
    // possible before needing to shrink at all.
    final segmentHorizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? AppSpacing.xs
        : AppSpacing.sm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cow Bull Quest'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: CoinBalanceBadge(balance: widget.coinBalance)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HomeHeroCard(),
              const SizedBox(height: AppSpacing.md),
              _StreakSummaryRow(
                currentStreak: widget.currentStreak,
                longestStreak: widget.longestStreak,
                shareCardRenderer: widget.shareCardRenderer,
                shareCardService: widget.shareCardService,
              ),
              const SizedBox(height: AppSpacing.md),
              _DailyChallengeCard(
                dateLabel: widget.dailyChallengeDateLabel,
                status: widget.dailyChallengeStatus,
                onTap: widget.onOpenDailyChallenge,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Guess the secret word. Each guess earns a bull for every '
                'letter that is correct and in the right position, and a '
                'cow for every letter that is correct but in the wrong '
                'position. Every game uses a 4-letter secret word and gives '
                'you 10 attempts.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Difficulty', style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Difficulty only changes which words the game can '
                        'pick from.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Semantics(
                        container: true,
                        label: 'Difficulty selection',
                        child: SegmentedButton<DifficultyOption>(
                          // The default checkmark overlay would otherwise
                          // replace each segment's own icon once selected;
                          // this option keeps the filled/outlined icon swap
                          // in [_difficultyIcon] itself visible instead, as
                          // the "icon state" cue for the current selection.
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: segmentHorizontalPadding,
                            ),
                          ),
                          segments: [
                            for (final option in DifficultyOption.values)
                              ButtonSegment(
                                value: option,
                                icon: Icon(
                                  _difficultyIcon(
                                    option,
                                    selected: option == _selectedDifficulty,
                                  ),
                                  size: 18,
                                ),
                                label: _SegmentLabel(_difficultyLabel(option)),
                              ),
                          ],
                          selected: {_selectedDifficulty},
                          onSelectionChanged: (selection) {
                            final chosen = selection.first;
                            setState(() => _selectedDifficulty = chosen);
                            widget.onDifficultySelected?.call(chosen);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final option in DifficultyOption.values)
                        _DifficultyDescriptionRow(
                          label: _difficultyLabel(option),
                          description: _difficultyDescription(option),
                          selected: option == _selectedDifficulty,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton.icon(
                onPressed: _handleStart,
                icon: const Icon(Icons.play_arrow),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Start Game'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: Divider(color: colorScheme.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      'more options',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: colorScheme.outlineVariant)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: widget.onOpenRules,
                icon: const Icon(Icons.menu_book),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('How to Play'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: widget.onOpenSettings,
                icon: const Icon(Icons.settings),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Settings'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: widget.onOpenStatistics,
                icon: const Icon(Icons.bar_chart),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Statistics'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the difficulty legend beneath the selector: a label and its
/// concise description, always visible for all three options so a player
/// can compare them before choosing. [selected] makes the currently chosen
/// option visually distinct (bold label, check icon, and a subtly tinted
/// background that animates in) without relying on color alone, and is
/// mirrored into the row's [Semantics] label.
class _DifficultyDescriptionRow extends StatelessWidget {
  const _DifficultyDescriptionRow({
    required this.label,
    required this.description,
    required this.selected,
  });

  final String label;
  final String description;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      excludeSemantics: true,
      label: selected
          ? '$label, selected: $description'
          : '$label: $description',
      child: AnimatedContainer(
        duration: AppMotion.durationFor(context, AppMotion.fast),
        curve: AppMotion.curve,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              child: selected ? const Icon(Icons.check, size: 18) : null,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // A trailing colon distinguishes this from the plain
                    // "$label" text already shown on the SegmentedButton
                    // segment above, so widget tests (and finders in
                    // general) can target either unambiguously.
                    '$label:',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  Text(description, style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A segmented-button label that always stays on one line.
///
/// Root cause of the "Medium" (and other segment labels) wrapping bug: at
/// narrow widths or large text-scale factors, a segment's available width
/// can be less than its label's natural single-line width, and a plain
/// [Text] (which defaults to wrapping) breaks onto a second line instead of
/// shrinking. [maxLines]/[softWrap] here force the [Text] to only ever
/// consider a single line, and the surrounding [FittedBox] then uniformly
/// scales that single line down to fit whatever width the segment actually
/// has, so it never wraps and never overflows/clips. A small,
/// selector-specific font size ([TextTheme.labelMedium], smaller than the
/// segmented button's own default label style) reduces how often that
/// scaling has to kick in at all, but is deliberately not relied on as the
/// only safeguard. The underlying [Text.data] — and therefore the
/// semantics label the platform announces for this segment — is unchanged
/// by the visual scaling, so the full, complete label is still announced.
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

/// A compact row showing the player's current daily-play streak with a
/// flame icon, and the longest streak ever reached in a smaller, less
/// prominent line beneath it.
///
/// A zero streak is deliberately never styled as an error/warning — no red,
/// no "broken" iconography. Always uses the same rounded flame glyph
/// (rather than switching to an outlined variant for zero, the way
/// [_difficultyIcon] does for the difficulty selector) specifically so it
/// never collides with the Hard-difficulty segment's own
/// `Icons.local_fire_department`/`Icons.local_fire_department_outlined`
/// icons elsewhere on this same screen; the muted color plus the
/// always-visible "N-day streak" text is what distinguishes a zero streak,
/// never color alone.
class _StreakSummaryRow extends StatelessWidget {
  const _StreakSummaryRow({
    required this.currentStreak,
    required this.longestStreak,
    required this.shareCardRenderer,
    required this.shareCardService,
  });

  final int currentStreak;
  final int longestStreak;
  final ShareCardRenderer shareCardRenderer;
  final ShareCardService shareCardService;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final active = currentStreak > 0;
    final flameColor = active
        ? (statusColors?.success ?? colorScheme.tertiary)
        : colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            label:
                '$currentStreak-day streak. '
                'Best: ${_dayCount(longestStreak)}.',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: flameColor,
                    size: 26,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$currentStreak-day streak',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Best: ${_dayCount(longestStreak)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
        ),
        // Deliberately a sibling of the Semantics/ExcludeSemantics pair
        // above, not a child of it — so this button keeps its own
        // accessible name ("Share streak") rather than being silently
        // excluded from the accessibility tree along with the rest of this
        // row.
        ShareStreakButton(
          currentStreak: currentStreak,
          renderer: shareCardRenderer,
          service: shareCardService,
        ),
      ],
    );
  }

  String _dayCount(int days) => '$days ${days == 1 ? 'day' : 'days'}';
}

/// The map from [DailyChallengeCardStatus] to its short trailing-chip label.
String _dailyChallengeStatusLabel(DailyChallengeCardStatus status) =>
    switch (status) {
      DailyChallengeCardStatus.notPlayed => 'Not played',
      DailyChallengeCardStatus.completedWon => 'Completed · Won',
      DailyChallengeCardStatus.completedNotSolved => 'Completed · Not solved',
    };

/// A single, clearly-labelled entry point to the Daily Challenge: today's
/// date, a completion-state chip, and — for a completed challenge — the
/// outcome, never the secret word.
class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard({
    required this.dateLabel,
    required this.status,
    required this.onTap,
  });

  final String dateLabel;
  final DailyChallengeCardStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final completed = status != DailyChallengeCardStatus.notPlayed;
    final won = status == DailyChallengeCardStatus.completedWon;
    final statusLabel = _dailyChallengeStatusLabel(status);
    final chipColor = won
        ? (statusColors?.success ?? colorScheme.tertiary)
        : (completed ? colorScheme.secondary : colorScheme.onSurfaceVariant);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: 'Daily Challenge, $dateLabel. $statusLabel.',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    completed ? Icons.event_available : Icons.event,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Daily Challenge', style: textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs / 2),
                        Text(
                          dateLabel,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs / 2,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: chipColor),
                      ),
                      child: Text(
                        statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: chipColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact, branded header card: the approved launcher-icon emblem next
/// to the app title and a short tagline, on a small navy/royal-blue
/// gradient surface — the app's one deliberately-branded, non-flat surface
/// (see CLAUDE.md Part 6: built-in [Container]/[BoxDecoration] gradients are
/// acceptable for a small number of surfaces like this one).
///
/// The icon is purely decorative here — [ExcludeSemantics] keeps it out of
/// the accessibility tree — because the adjacent [Semantics.header] title
/// text already announces "Cow Bull Quest" once; without that exclusion a
/// screen reader would announce the app name twice in a row for no benefit.
class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard();

  static const Color _heroForeground = Color(0xFFF5F7FB);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    // Kept modest and responsive so the emblem never dominates the page: a
    // little smaller on narrow phones, capped well below the hero card's
    // own height on any device.
    final iconSize = MediaQuery.sizeOf(context).width < 360 ? 44.0 : 52.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF071525), Color(0xFF2457D6)]
              : const [Color(0xFF244FB5), Color(0xFF195FC8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/branding/cow_bull_quest_icon.png',
                width: iconSize,
                height: iconSize,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Cow Bull Quest',
                    style: textTheme.headlineSmall?.copyWith(
                      color: _heroForeground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A word-guessing game of bulls and cows.',
                  style: textTheme.bodySmall?.copyWith(
                    color: _heroForeground.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
