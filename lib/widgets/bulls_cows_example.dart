import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A letter's status within [BullsCowsExample]'s worked guess.
enum _LetterStatus { bull, cow, absent }

/// A fixed, fictional 4-letter worked example: secret "PLAN", guess "LAWN".
/// Deliberately unrelated to any real secret word or word pool — see the
/// class-level doc on [BullsCowsExample] — and deliberately has one Bull
/// (N), two Cows (L, A), and one absent letter (W), so every state this
/// widget explains actually appears once.
const String _exampleSecret = 'PLAN';
const String _exampleGuess = 'LAWN';

/// Per-letter statuses for [_exampleGuess] against [_exampleSecret], in
/// guess order: L is a Cow (in the word, wrong spot), A is a Cow, W is
/// absent, N is a Bull.
const List<_LetterStatus> _exampleStatuses = [
  _LetterStatus.cow,
  _LetterStatus.cow,
  _LetterStatus.absent,
  _LetterStatus.bull,
];

/// A compact, reusable worked example explaining Bulls, Cows, and an absent
/// letter, shared by onboarding and the Rules screen (see CLAUDE.md —
/// presentation-only widgets used by 2+ features live under `widgets/`).
///
/// Always uses the same hardcoded, fictional secret/guess pair
/// ([_exampleSecret]/[_exampleGuess]) — never the real, active or Daily
/// Challenge secret word, and never anything read from
/// `WordRepository`/`AssetWordRepository` — so this widget cannot leak or
/// hint at any real game's answer. A real completed guess only ever shows
/// aggregate Bulls/Cows counts (see `GuessHistoryTile`), never a per-letter
/// breakdown; the caption beneath this example makes that distinction
/// explicit so a player never expects per-letter feedback in real gameplay.
///
/// Every letter's status is conveyed by an icon, a text label, and a
/// distinct border/fill style — never by color alone — so it reads
/// correctly for a color-blind player or a screen reader alike. Wrapped in
/// a [Wrap] (not a fixed-width [Row]) so it never overflows at large text
/// scale or on narrow screens.
class BullsCowsExample extends StatelessWidget {
  const BullsCowsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bulls = _exampleStatuses
        .where((status) => status == _LetterStatus.bull)
        .length;
    final cows = _exampleStatuses
        .where((status) => status == _LetterStatus.cow)
        .length;

    final semanticsLabel = StringBuffer(
      'Example: secret word $_exampleSecret, guess $_exampleGuess. '
      'Result: $bulls ${bulls == 1 ? 'bull' : 'bulls'}, '
      '$cows ${cows == 1 ? 'cow' : 'cows'}. ',
    );
    for (var i = 0; i < _exampleGuess.length; i++) {
      final letter = _exampleGuess[i];
      final label = switch (_exampleStatuses[i]) {
        _LetterStatus.bull => 'Bull',
        _LetterStatus.cow => 'Cow',
        _LetterStatus.absent => 'not in the word',
      };
      semanticsLabel.write('$letter: $label. ');
    }

    return Semantics(
      container: true,
      label: semanticsLabel.toString(),
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secret word: $_exampleSecret   Your guess: $_exampleGuess',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < _exampleGuess.length; i++)
                      _LetterTile(
                        letter: _exampleGuess[i],
                        status: _exampleStatuses[i],
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Result: $bulls ${bulls == 1 ? 'Bull' : 'Bulls'}, '
                  '$cows ${cows == 1 ? 'Cow' : 'Cows'}.',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A real guess only shows these totals, not which letter '
                  'earned each one. This example spells it out to explain '
                  'the idea.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.letter, required this.status});

  final String letter;
  final _LetterStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, label, background, foreground, borderStyle) = switch (status) {
      _LetterStatus.bull => (
        Icons.gps_fixed,
        'Bull',
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        BorderStyle.solid,
      ),
      _LetterStatus.cow => (
        Icons.sync_alt,
        'Cow',
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        BorderStyle.solid,
      ),
      _LetterStatus.absent => (
        Icons.remove_circle_outline,
        'Not in word',
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
        BorderStyle.none,
      ),
    };

    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: foreground, style: borderStyle, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            letter.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Icon(icon, size: 16, color: foreground),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: foreground),
          ),
        ],
      ),
    );
  }
}
