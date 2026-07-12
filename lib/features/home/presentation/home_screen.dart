import 'package:flutter/material.dart';

import '../../../models/difficulty_selection.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_spacing.dart';

/// Concise, human-facing label for [option]. Presentation-layer concern —
/// [DifficultyOption] itself carries no human-facing text.
String _difficultyLabel(DifficultyOption option) => switch (option) {
  DifficultyOption.easy => 'Easy',
  DifficultyOption.common => 'Common',
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
/// secret-word length (4, 5, or 6 letters) and difficulty (Easy, Common, or
/// Hard), and entry points to starting a game, How to Play, and Settings.
///
/// Purely presentational and feature-local — it owns only the selected word
/// length (a plain `int`) and difficulty (the shared, feature-neutral
/// [DifficultyOption]) as local state, and never imports anything from the
/// `game`, `rules`, or `settings` features (no `GameConfig`, no
/// `GameDifficulty`, no repository, no engine, no controller, no other
/// feature's screen). All three actions are handed off entirely to
/// [onStartGame], [onOpenRules], and [onOpenSettings], which the app-level
/// composition root supplies; that composition root is the one place that
/// turns the chosen length and difficulty into a `GameConfig` via
/// `GameConfig.forSelection` and owns navigation to the other screens.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onStartGame,
    required this.onOpenRules,
    required this.onOpenSettings,
  });

  /// Called with the chosen word length (4, 5, or 6) and difficulty when
  /// the player starts a game.
  final void Function(int wordLength, DifficultyOption difficulty) onStartGame;

  /// Called when the player wants to see the How to Play screen.
  final VoidCallback onOpenRules;

  /// Called when the player wants to see the Settings screen.
  final VoidCallback onOpenSettings;

  static const List<int> _wordLengthOptions = [4, 5, 6];

  /// The difficulty preselected when Home first appears. `common` — the
  /// broadest, middle-of-the-road pool — is the least surprising default
  /// for a first-time player, neither the easiest nor the hardest option.
  static const DifficultyOption _defaultDifficulty = DifficultyOption.common;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedWordLength = HomeScreen._wordLengthOptions.first;
  DifficultyOption _selectedDifficulty = HomeScreen._defaultDifficulty;

  void _handleStart() {
    widget.onStartGame(_selectedWordLength, _selectedDifficulty);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Bulls & Cows')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Bulls & Cows',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Guess the secret word. Each guess earns a bull for every '
                'letter that is correct and in the right position, and a '
                'cow for every letter that is correct but in the wrong '
                'position.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Word length', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                container: true,
                label: 'Word length selection',
                child: SegmentedButton<int>(
                  segments: [
                    for (final length in HomeScreen._wordLengthOptions)
                      ButtonSegment(
                        value: length,
                        label: Text('$length letters'),
                      ),
                  ],
                  selected: {_selectedWordLength},
                  onSelectionChanged: (selection) =>
                      setState(() => _selectedWordLength = selection.first),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedSwitcher(
                duration: AppMotion.durationFor(context, AppMotion.fast),
                switchInCurve: AppMotion.curve,
                child: Text(
                  'You\'ll guess a $_selectedWordLength-letter secret word.',
                  key: ValueKey(_selectedWordLength),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Difficulty', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                container: true,
                label: 'Difficulty selection',
                child: SegmentedButton<DifficultyOption>(
                  segments: [
                    for (final option in DifficultyOption.values)
                      ButtonSegment(
                        value: option,
                        label: Text(_difficultyLabel(option)),
                      ),
                  ],
                  selected: {_selectedDifficulty},
                  onSelectionChanged: (selection) =>
                      setState(() => _selectedDifficulty = selection.first),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final option in DifficultyOption.values)
                _DifficultyDescriptionRow(
                  label: _difficultyLabel(option),
                  description: _difficultyDescription(option),
                  selected: option == _selectedDifficulty,
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
