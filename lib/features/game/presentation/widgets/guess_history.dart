import 'package:flutter/material.dart';

import '../../models/guess.dart';
import 'guess_history_tile.dart';

/// The list of guesses made so far in a session.
///
/// Displayed newest-first: the most recent guess's feedback is what the
/// player needs to see next, and with attempt limits of up to 20 a
/// newest-first list keeps it visible without scrolling.
class GuessHistory extends StatelessWidget {
  const GuessHistory({super.key, required this.guesses});

  /// The guesses made so far, oldest first (as produced by [GameSession]).
  final List<Guess> guesses;

  @override
  Widget build(BuildContext context) {
    if (guesses.isEmpty) {
      return const Center(
        child: Text('No guesses yet. Make your first guess!'),
      );
    }

    final newestFirst = guesses.reversed.toList();
    return ListView.builder(
      itemCount: newestFirst.length,
      itemBuilder: (context, index) =>
          GuessHistoryTile(guess: newestFirst[index]),
    );
  }
}
