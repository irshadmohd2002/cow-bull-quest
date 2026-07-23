import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';
import '../../../widgets/bulls_cows_example.dart';
import '../../../widgets/cow_head_icon.dart';
import '../../../widgets/guess_result_badge.dart';

/// Explains how Bulls & Cows is played.
///
/// Purely presentational and feature-local: it imports nothing from the
/// `game` feature. Every game always uses a 4-letter secret word and 10
/// attempts (see Milestone 12), so that fact is stated directly as plain
/// copy here rather than read from `GameConfig`.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, required this.onViewTutorial});

  /// Called when the player taps "View Tutorial" to (re)watch the
  /// first-launch onboarding walkthrough. Reopening it this way never
  /// resets or alters any other app data — see `OnboardingScreen`'s own
  /// doc. This entry point exists alongside the one in Settings so the
  /// tutorial is reachable from either natural "help" destination.
  final VoidCallback onViewTutorial;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Play'),
        actions: [
          Semantics(
            button: true,
            label: 'View Tutorial',
            child: ExcludeSemantics(
              child: TextButton.icon(
                onPressed: onViewTutorial,
                icon: const Icon(Icons.school_outlined),
                label: const Text('Tutorial'),
              ),
            ),
          ),
        ],
      ),
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
                'You guess a secret 4-letter English word. After each '
                'guess, you are told how many letters you got right.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading('Scoring'),
              const SizedBox(height: AppSpacing.sm),
              Card(
                key: const Key('rules_scoring_section'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RuleItem(
                        icon: Icons.gps_fixed_rounded,
                        heading: 'Bulls',
                        explanation:
                            'A bull is a letter that is correct and in the '
                            'right position.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RuleItem(
                        iconWidget: CowHeadIcon(
                          size: 24,
                          color: colorScheme.secondary,
                        ),
                        heading: 'Cows',
                        explanation:
                            'A cow is a letter that is correct but in the '
                            'wrong position.',
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
              const SizedBox(height: AppSpacing.md),
              const BullsCowsExample(),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading('Difficulty'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Difficulty only changes which vocabulary the secret word '
                'is drawn from. Every game uses a 4-letter secret word and '
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
              _SectionHeading('Coin Rewards'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Winning a game earns coins based on its difficulty, with '
                'bonuses for winning without a hint. Coins and progress '
                'never leave this device.',
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
                        icon: Icons.emoji_events,
                        heading: 'Easy win',
                        explanation: '10 coins.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RuleItem(
                        icon: Icons.emoji_events,
                        heading: 'Medium win',
                        explanation: '15 coins.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RuleItem(
                        icon: Icons.emoji_events,
                        heading: 'Hard win',
                        explanation: '20 coins.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RuleItem(
                        icon: Icons.stars,
                        heading: 'No-hint win bonus',
                        explanation: '+5 coins for winning without a hint.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RuleItem(
                        icon: Icons.event_available,
                        heading: 'First official Daily Challenge win',
                        explanation:
                            '+10 coins, on top of the Medium win reward, '
                            'once per calendar day, for your first attempt '
                            'only.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _RuleItem(
                        icon: Icons.lightbulb_outline,
                        heading: 'Paid hints cost 20 coins',
                        explanation:
                            "Hard's first hint is free; every other hint "
                            'costs 20 coins.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading('Daily Streak'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Complete at least one game (normal or Daily Challenge, won '
                'or lost) on a calendar day to keep your streak going. Only '
                'one streak day can be earned per calendar date, and your '
                'streak is tracked locally, on this device.',
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
                        icon: Icons.local_fire_department,
                        heading: 'Wins and losses both count',
                        explanation:
                            'A completed game earns the day\'s streak '
                            'whether you win or lose. Only an abandoned or '
                            'restarted game does not count.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _RuleItem(
                        icon: Icons.event_busy,
                        heading: 'Missed days',
                        explanation:
                            'Missing one or more calendar days resets your '
                            'current streak to 1 the next time you complete '
                            'a qualifying game.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _RuleItem(
                        icon: Icons.smartphone,
                        heading: 'Offline and device-based',
                        explanation:
                            'Your streak is computed entirely on this '
                            'device, with no internet time or server check. '
                            'Changing the device clock can affect it.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading('Daily Challenge'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'One extra puzzle a day, using Medium rules, the same for '
                'everyone on the same word-list version, computed entirely '
                'offline for that calendar date.',
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
                        icon: Icons.event_available,
                        heading: 'Same puzzle for everyone',
                        explanation:
                            'Every player on the same app word-list version '
                            'gets the same offline Daily Challenge word for '
                            'a given date.',
                        iconColor: colorScheme.tertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _RuleItem(
                        icon: Icons.balance,
                        heading: 'Medium rules',
                        explanation:
                            'The Daily Challenge always uses Medium '
                            'difficulty rules: a 4-letter word and one '
                            '20-coin hint.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _RuleItem(
                        icon: Icons.storage,
                        heading: 'Stored only on this device',
                        explanation:
                            'Your Daily Challenge result is saved locally, '
                            'never sent anywhere. Changing the device date '
                            'can also change which puzzle "today" maps to.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _RuleItem(
                        icon: Icons.replay,
                        heading: 'Replays earn no coins',
                        explanation:
                            'Only your first attempt each day is official '
                            'and earns coins. Replaying afterward is great '
                            'practice, but since you already know the word, '
                            'it never earns any coins at all.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading('Examples'),
              const SizedBox(height: AppSpacing.md),
              const _RuleExample(
                secretWord: 'LAMP',
                guessWord: 'LAMB',
                bulls: 3,
                cows: 0,
                explanation:
                    'L, A, and M all match in position, so that is 3 '
                    "bulls. The guess's B does not appear anywhere in "
                    'LAMP, so there are 0 cows.',
              ),
              const SizedBox(height: AppSpacing.md),
              const _RuleExample(
                secretWord: 'SEED',
                guessWord: 'DEER',
                bulls: 2,
                cows: 1,
                explanation:
                    'Both Es match in position, so that is 2 bulls. The '
                    "guess's D is in SEED but at a different position, so "
                    "that is 1 cow. The guess's R does not appear anywhere "
                    'in SEED, so it adds nothing.',
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
    this.icon,
    this.iconWidget,
    required this.heading,
    required this.explanation,
    this.iconColor,
  }) : assert(
         (icon == null) != (iconWidget == null),
         'Provide exactly one of icon or iconWidget.',
       );

  /// A [Material] glyph. Mutually exclusive with [iconWidget], which is used
  /// instead for icons with no [IconData] equivalent (e.g. [CowHeadIcon]).
  final IconData? icon;

  /// A fully custom leading icon, e.g. [CowHeadIcon]. Mutually exclusive
  /// with [icon].
  final Widget? iconWidget;

  final String heading;
  final String explanation;

  /// Overrides [icon]'s color; defaults to [ColorScheme.primary]. Ignored
  /// when [iconWidget] is used — that widget colors itself. Used to mirror
  /// the Bulls/Cows badge colors already used on the Game screen (cyan
  /// tertiary for Bulls) so the same concept reads with the same accent
  /// color everywhere it appears.
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
          iconWidget ?? Icon(icon, color: iconColor ?? colorScheme.primary),
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
    final bullWord = bulls == 1 ? 'bull' : 'bulls';
    final cowWord = cows == 1 ? 'cow' : 'cows';
    return Semantics(
      excludeSemantics: true,
      container: true,
      label:
          'Example: secret word $secretWord, guess $guessWord. '
          'Result: $bulls $bullWord, $cows $cowWord. $explanation',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Secret: $secretWord'),
              Text('Guess: $guessWord'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  GuessResultBadge(
                    type: GuessResultBadgeType.bull,
                    count: bulls,
                  ),
                  GuessResultBadge(type: GuessResultBadgeType.cow, count: cows),
                ],
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
