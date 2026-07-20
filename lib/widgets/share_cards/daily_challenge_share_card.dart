import 'package:flutter/material.dart';

import '../../models/daily_challenge_share_data.dart';
import '../../theme/share_card_palette.dart';
import 'branded_share_card_frame.dart';

/// The share card for the official (first-of-the-day) Daily Challenge win.
///
/// Purely presentational: receives immutable [data] — always mapped from the
/// official saved result, never a live/replayed session — and renders it.
/// Never shows the secret word, guessed words, or the guess history.
class DailyChallengeShareCard extends StatelessWidget {
  const DailyChallengeShareCard({super.key, required this.data});

  final DailyChallengeShareData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Cow Bull Quest Daily Challenge card. ${data.dateLabel}. Solved. '
          '${data.attemptsLabel}. ${data.hintsLabel}.'
          '${data.coinsEarned > 0 ? ' Plus ${data.coinsEarned} coins.' : ''}'
          '${data.currentStreak > 0 ? ' Current streak: ${data.currentStreak} days.' : ''}',
      child: ExcludeSemantics(
        child: BrandedShareCardFrame(
          topLabel: 'DAILY CHALLENGE',
          subLabel: data.dateLabel,
          footerText: "Can you beat today's challenge?",
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
                    fontSize: 36,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
              if (data.currentStreak > 0)
                ShareCardDetailRow(
                  icon: Icons.local_fire_department,
                  label: '${data.currentStreak}-day streak',
                  iconColor: ShareCardPalette.gold,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
