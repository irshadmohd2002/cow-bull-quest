import 'package:flutter/material.dart';

import '../../models/guess.dart';

/// One row of guess history: the turn number, the guessed word, and its
/// scored bulls/cows — always as visible text, never conveyed by color
/// alone.
class GuessHistoryTile extends StatelessWidget {
  const GuessHistoryTile({super.key, required this.guess});

  final Guess guess;

  @override
  Widget build(BuildContext context) {
    final bulls = guess.result.bulls;
    final cows = guess.result.cows;

    return Semantics(
      label:
          'Guess ${guess.turnNumber}: ${guess.word}, '
          '$bulls ${bulls == 1 ? 'bull' : 'bulls'}, '
          '$cows ${cows == 1 ? 'cow' : 'cows'}',
      child: ListTile(
        leading: CircleAvatar(child: Text('${guess.turnNumber}')),
        title: Text(
          guess.word.toUpperCase(),
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bulls: $bulls'),
            const SizedBox(width: 12),
            Text('Cows: $cows'),
          ],
        ),
      ),
    );
  }
}
