import 'package:flutter/material.dart';

/// The app's entry screen: a brief explanation of the game and a choice of
/// secret-word length (4, 5, or 6 letters) that starts a game.
///
/// Purely presentational and feature-local — it owns only the selected word
/// length as a plain `int` and never imports anything from the `game`
/// feature (no `GameConfig`, no repository, no engine, no controller).
/// Starting a game is handed off entirely to [onStartGame], which the
/// app-level composition root supplies; that composition root is the one
/// place that turns the chosen length into a `GameConfig` via
/// `GameConfig.forWordLength`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onStartGame});

  /// Called with the chosen word length (4, 5, or 6) when the player starts
  /// a game.
  final ValueChanged<int> onStartGame;

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
            ],
          ),
        ),
      ),
    );
  }
}
