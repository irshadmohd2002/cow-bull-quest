import 'package:flutter/material.dart';

import '../../models/streak_share_data.dart';
import '../../theme/share_card_palette.dart';
import 'branded_share_card_frame.dart';

/// The share card for the player's current daily-play streak.
///
/// A focused celebratory badge: no coins, attempts, hints, wins, losses, or
/// generic achievement copy — only the streak count, its exact milestone
/// conversion (if any), and the fixed footer question. Purely
/// presentational: receives immutable [data] and renders it.
class StreakShareCard extends StatelessWidget {
  const StreakShareCard({super.key, required this.data});

  final StreakShareData data;

  @override
  Widget build(BuildContext context) {
    final milestone = data.milestoneLabel;
    return Semantics(
      label:
          'Cow Bull Quest streak card. ${data.primaryLabel}.'
          '${milestone != null ? ' $milestone.' : ''}',
      child: ExcludeSemantics(
        child: BrandedShareCardFrame(
          topLabel: 'STREAK',
          footerText: "What's your biggest streak?",
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_fire_department,
                color: ShareCardPalette.gold,
                size: 76,
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  data.primaryLabel,
                  maxLines: 1,
                  style: const TextStyle(
                    color: ShareCardPalette.cyan,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (milestone != null) ...[
                const SizedBox(height: 8),
                ShareCardBadge(text: milestone),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
