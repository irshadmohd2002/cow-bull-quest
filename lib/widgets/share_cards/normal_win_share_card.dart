import 'package:flutter/material.dart';

import '../../models/normal_win_share_data.dart';
import '../../theme/share_card_palette.dart';
import 'branded_share_card_frame.dart';

/// The share card for winning a normal Easy/Medium/Hard game.
///
/// Purely presentational: receives immutable [data] and renders it, reading
/// no controller or repository itself. Never shows streak details, Daily
/// Challenge wording, the secret word, guessed words, or the guess history —
/// see [NormalWinShareData]'s own privacy scope.
class NormalWinShareCard extends StatelessWidget {
  const NormalWinShareCard({super.key, required this.data});

  final NormalWinShareData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Cow Bull Quest result card. Solved. Difficulty: '
          '${data.difficultyLabel}. ${data.attemptsLabel}. ${data.hintsLabel}.'
          '${data.coinsEarned > 0 ? ' Plus ${data.coinsEarned} coins.' : ''}',
      child: ExcludeSemantics(
        child: BrandedShareCardFrame(
          topLabel: 'RESULT',
          footerText: 'Can you solve it too?',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'SOLVED',
                  maxLines: 1,
                  style: TextStyle(
                    color: ShareCardPalette.cyan,
                    fontWeight: FontWeight.w900,
                    fontSize: 40,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: ShareCardBadge(text: data.difficultyLabel.toUpperCase()),
              ),
              const SizedBox(height: 16),
              ShareCardDetailRow(
                icon: Icons.flag_circle,
                label: '${data.attemptsLabel}.',
              ),
              ShareCardDetailRow(
                icon: Icons.lightbulb,
                label: '${data.hintsLabel}.',
              ),
              if (data.coinsEarned > 0)
                ShareCardDetailRow(
                  icon: Icons.paid,
                  label: '+${data.coinsEarned} coins',
                  iconColor: ShareCardPalette.gold,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
