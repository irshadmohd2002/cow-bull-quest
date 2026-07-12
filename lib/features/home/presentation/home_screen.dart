import 'package:flutter/material.dart';

import '../../../models/difficulty_selection.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Bulls & Cows')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bulls & Cows',
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Guess the secret word. Each guess earns a bull for every '
                'letter that is correct and in the right position, and a '
                'cow for every letter that is correct but in the wrong '
                'position.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text('Word length', style: textTheme.titleMedium),
              const SizedBox(height: 8),
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
              const SizedBox(height: 32),
              Text('Difficulty', style: textTheme.titleMedium),
              const SizedBox(height: 8),
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
              const SizedBox(height: 12),
              for (final option in DifficultyOption.values)
                _DifficultyDescriptionRow(
                  label: _difficultyLabel(option),
                  description: _difficultyDescription(option),
                  selected: option == _selectedDifficulty,
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _handleStart,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Start Game'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: widget.onOpenRules,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('How to Play'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onOpenSettings,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
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
/// option visually distinct (bold label plus a check icon) without relying
/// on color alone, and is mirrored into the row's [Semantics] label.
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: selected
            ? '$label, selected: $description'
            : '$label: $description',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              child: selected ? const Icon(Icons.check, size: 18) : null,
            ),
            const SizedBox(width: 4),
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
