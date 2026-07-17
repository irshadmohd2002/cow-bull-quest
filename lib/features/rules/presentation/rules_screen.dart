import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';

/// Explains how Bulls & Cows is played.
///
/// Purely presentational and feature-local: it imports nothing from the
/// `game` feature. Every game always uses a 4-letter secret word and 10
/// attempts (see Milestone 12), so that fact is stated directly as plain
/// copy here rather than read from `GameConfig`.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('How to Play')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'How to Play',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'You guess a secret English word. After each guess, you '
                'are told how many letters you got right.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading('Scoring'),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RuleItem(
                        icon: Icons.gps_fixed,
                        heading: 'Bulls',
                        explanation:
                            'A bull is a letter that is correct and in the '
                            'right position.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RuleItem(
                        icon: Icons.sync_alt,
                        heading: 'Cows',
                        explanation:
                            'A cow is a letter that is correct but in the '
                            'wrong position.',
                        iconColor: colorScheme.secondary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _RuleItem(
                        icon: Icons.content_copy,
                        heading: 'Duplicate letters',
                        explanation:
                            'A letter can never be counted more times than '
                            'it appears in the secret word, even if your '
                            'guess repeats it more often.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _RuleItem(
                        icon: Icons.block,
                        heading: 'Invalid guesses',
                        explanation:
                            'A guess that is blank, the wrong length, or '
                            'contains anything other than letters is '
                            'rejected and does not use up an attempt.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading('Difficulty'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Difficulty only changes which vocabulary the secret word '
                'is drawn from — every game uses a 4-letter secret word and '
                'gives you 10 attempts to guess it, no matter which '
                'difficulty you pick.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RuleItem(
                        icon: Icons.sentiment_satisfied_alt,
                        heading: 'Easy',
                        explanation: 'Familiar, high-frequency words.',
                      ),
                      SizedBox(height: AppSpacing.md),
                      _RuleItem(
                        icon: Icons.balance,
                        heading: 'Medium',
                        explanation: 'Broader everyday vocabulary.',
                      ),
                      SizedBox(height: AppSpacing.md),
                      _RuleItem(
                        icon: Icons.local_fire_department,
                        heading: 'Hard',
                        explanation: 'Less frequent words.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading('Coins & Hints'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'New players begin with 100 coins, stored only on this '
                'device. A hint reveals one correct letter and its exact '
                'position in the secret word, and never uses up an '
                'attempt.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RuleItem(
                        icon: Icons.monetization_on,
                        heading: 'Starting coins',
                        explanation: 'Every new player begins with 100 coins.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RuleItem(
                        icon: Icons.lightbulb_outline,
                        heading: 'Easy and Medium hints',
                        explanation: 'One hint per game, costing 20 coins.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RuleItem(
                        icon: Icons.lightbulb,
                        heading: 'Hard hints',
                        explanation:
                            'Up to two hints per game: the first is free, '
                            'the second costs 20 coins.',
                        iconColor: colorScheme.tertiary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading('Examples'),
              const SizedBox(height: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.md),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({
    required this.icon,
    required this.heading,
    required this.explanation,
    this.iconColor,
  });

  final IconData icon;
  final String heading;
  final String explanation;

  /// Overrides the icon's color; defaults to [ColorScheme.primary]. Used to
  /// mirror the Bulls/Cows badge colors already used on the Game screen
  /// (cyan tertiary for Bulls, blue secondary for Cows) so the same concept
  /// reads with the same accent color everywhere it appears.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      excludeSemantics: true,
      container: true,
      label: '$heading: $explanation',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor ?? colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(explanation),
              ],
            ),
          ),
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
      excludeSemantics: true,
      container: true,
      label:
          'Example: secret word $secretWord, guess $guessWord. '
          'Result: $bulls bulls, $cows cows. $explanation',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Secret: $secretWord'),
              Text('Guess: $guessWord'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Bulls: $bulls   Cows: $cows',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(explanation),
            ],
          ),
        ),
      ),
    );
  }
}
