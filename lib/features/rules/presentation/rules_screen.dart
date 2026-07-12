import 'package:flutter/material.dart';

/// Explains how Bulls & Cows is played.
///
/// Purely presentational and feature-local: it imports nothing from the
/// `game` feature. The attempt-limit numbers shown per word length are
/// display data only — a presentation-neutral `Map<int, int>` of word
/// length to attempt limit — supplied by the app-level composition root
/// (which is the only place permitted to read them from `GameConfig`), so
/// this feature never needs to import `GameConfig` just to read that
/// mapping.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, required this.attemptLimitsByWordLength});

  /// Word length (4, 5, or 6) mapped to its attempt limit, supplied by the
  /// app-level composition root.
  final Map<int, int> attemptLimitsByWordLength;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sortedLengths = attemptLimitsByWordLength.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('How to Play')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('How to Play', style: textTheme.headlineMedium),
              const SizedBox(height: 16),
              const Text(
                'You guess a secret English word. After each guess, you '
                'are told how many letters you got right.',
              ),
              const SizedBox(height: 24),
              const _RuleItem(
                heading: 'Bulls',
                explanation:
                    'A bull is a letter that is correct and in the right '
                    'position.',
              ),
              const SizedBox(height: 16),
              const _RuleItem(
                heading: 'Cows',
                explanation:
                    'A cow is a letter that is correct but in the wrong '
                    'position.',
              ),
              const SizedBox(height: 16),
              const _RuleItem(
                heading: 'Duplicate letters',
                explanation:
                    'A letter can never be counted more times than it '
                    'appears in the secret word, even if your guess repeats '
                    'it more often.',
              ),
              const SizedBox(height: 16),
              const _RuleItem(
                heading: 'Invalid guesses',
                explanation:
                    'A guess that is blank, the wrong length, or contains '
                    'anything other than letters is rejected and does not '
                    'use up an attempt.',
              ),
              const SizedBox(height: 24),
              Text('Difficulty', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Difficulty only changes which secret words the game can '
                'pick from — it never changes scoring or attempt limits.',
              ),
              const SizedBox(height: 16),
              const _RuleItem(
                heading: 'Easy',
                explanation: 'Familiar, high-frequency words.',
              ),
              const SizedBox(height: 16),
              const _RuleItem(
                heading: 'Common',
                explanation: 'Broader everyday vocabulary.',
              ),
              const SizedBox(height: 16),
              const _RuleItem(
                heading: 'Hard',
                explanation: 'Less frequent words.',
              ),
              const SizedBox(height: 24),
              Text('Attempt limits', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final wordLength in sortedLengths)
                Text(
                  '$wordLength letters: '
                  '${attemptLimitsByWordLength[wordLength]} attempts',
                ),
              const SizedBox(height: 24),
              Text('Examples', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              const _RuleExample(
                secretWord: 'APPLE',
                guessWord: 'AMPLE',
                bulls: 4,
                cows: 0,
                explanation:
                    'A, P, L, and E all match in position, so that is 4 '
                    'bulls. The guess\'s M does not appear anywhere in '
                    'APPLE, so there are 0 cows.',
              ),
              const SizedBox(height: 12),
              const _RuleExample(
                secretWord: 'SPEED',
                guessWord: 'EERIE',
                bulls: 0,
                cows: 2,
                explanation:
                    'No letter matches in position, so that is 0 bulls. '
                    'SPEED contains exactly two Es; EERIE repeats E three '
                    'times, but only 2 of those count as cows — never more '
                    'than the letter actually appears in the secret word.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({required this.heading, required this.explanation});

  final String heading;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$heading: $explanation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(explanation),
        ],
      ),
    );
  }
}

/// A worked example showing a secret word, a guess, and the resulting
/// bulls/cows count, with the counts always conveyed as text (never by
/// color alone) and mirrored into a single [Semantics] label.
class _RuleExample extends StatelessWidget {
  const _RuleExample({
    required this.secretWord,
    required this.guessWord,
    required this.bulls,
    required this.cows,
    required this.explanation,
  });

  final String secretWord;
  final String guessWord;
  final int bulls;
  final int cows;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Example: secret word $secretWord, guess $guessWord. '
          'Result: $bulls bulls, $cows cows. $explanation',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Secret: $secretWord'),
              Text('Guess: $guessWord'),
              const SizedBox(height: 8),
              Text(
                'Bulls: $bulls   Cows: $cows',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(explanation),
            ],
          ),
        ),
      ),
    );
  }
}
