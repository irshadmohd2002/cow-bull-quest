import 'package:flutter/material.dart';

import '../../../models/difficulty_selection.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_spacing.dart';

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
      appBar: AppBar(title: const Text('Cow Bull Quest')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HomeHeroCard(),
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
                          style: SegmentedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: segmentHorizontalPadding,
                            ),
                          ),
                          segments: [
                            for (final option in DifficultyOption.values)
                              ButtonSegment(
                                value: option,
                                label: _SegmentLabel(_difficultyLabel(option)),
                              ),
                          ],
                          selected: {_selectedDifficulty},
                          onSelectionChanged: (selection) => setState(
                            () => _selectedDifficulty = selection.first,
                          ),
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
              FilledButton(
                onPressed: _handleStart,
                child: const Padding(
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
              OutlinedButton(
                onPressed: widget.onOpenRules,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('How to Play'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: widget.onOpenSettings,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Settings'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: widget.onOpenStatistics,
                child: const Padding(
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

  static const Color _heroForeground = Color(0xFFF8F4E8);

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
              ? const [Color(0xFF0B1026), Color(0xFF153B8C)]
              : const [Color(0xFF153B8C), Color(0xFF2560C7)],
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
