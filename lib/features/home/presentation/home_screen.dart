import 'package:flutter/material.dart';

/// The app's entry screen: a brief explanation of the game, a choice of
/// secret-word length (4, 5, or 6 letters), and entry points to starting a
/// game, How to Play, and Settings.
///
/// Purely presentational and feature-local — it owns only the selected word
/// length as a plain `int` and never imports anything from the `game`,
/// `rules`, or `settings` features (no `GameConfig`, no repository, no
/// engine, no controller, no other feature's screen). All three actions are
/// handed off entirely to [onStartGame], [onOpenRules], and [onOpenSettings],
/// which the app-level composition root supplies; that composition root is
/// the one place that turns the chosen length into a `GameConfig` via
/// `GameConfig.forWordLength` and owns navigation to the other screens.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onStartGame,
    required this.onOpenRules,
    required this.onOpenSettings,
  });

  /// Called with the chosen word length (4, 5, or 6) when the player starts
  /// a game.
  final ValueChanged<int> onStartGame;

  /// Called when the player wants to see the How to Play screen.
  final VoidCallback onOpenRules;

  /// Called when the player wants to see the Settings screen.
  final VoidCallback onOpenSettings;

  static const List<int> _wordLengthOptions = [4, 5, 6];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedWordLength = HomeScreen._wordLengthOptions.first;

  void _handleStart() {
    widget.onStartGame(_selectedWordLength);
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
