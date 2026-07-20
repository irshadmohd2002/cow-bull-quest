import 'package:flutter/material.dart';

import '../../theme/share_card_palette.dart';

/// The shared visual shell every share card renders inside: a fixed-size,
/// premium dark-navy panel with a gold border, the Cow Bull Quest emblem and
/// name, a short top label ("RESULT"/"DAILY CHALLENGE"/"STREAK"), the
/// card-specific [child] content, and a footer call-to-action line.
///
/// Always [logicalSize] square, laid out with its own explicit, fixed
/// [MediaQueryData] — never the ambient one — so the exported PNG is
/// pixel-identical regardless of the device's screen size, text-scale
/// factor, or active Light/Dark app theme (every color here comes from
/// [ShareCardPalette], never `Theme.of(context)`). [ShareCardRenderer]
/// captures exactly this logical size at `pixelRatio: 3.0`, producing a
/// 1080x1080 PNG.
class BrandedShareCardFrame extends StatelessWidget {
  const BrandedShareCardFrame({
    super.key,
    required this.topLabel,
    required this.footerText,
    required this.child,
    this.subLabel,
  });

  /// The logical (pre-`pixelRatio`) side length of the square card.
  static const double logicalSize = 360;

  static const String _emblemAsset = 'assets/branding/cow_bull_quest_icon.png';

  /// A short label under the app name, e.g. "RESULT" or "STREAK".
  final String topLabel;

  /// An optional second header line under [topLabel], e.g. a Daily
  /// Challenge date.
  final String? subLabel;

  /// The card-specific content, laid out between the header and footer.
  final Widget child;

  /// The footer call-to-action line, e.g. "Can you solve it too?".
  final String footerText;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(logicalSize, logicalSize),
        devicePixelRatio: 1,
        textScaler: TextScaler.noScaling,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: logicalSize,
          height: logicalSize,
          color: ShareCardPalette.background,
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ShareCardPalette.background, ShareCardPalette.surface],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ShareCardPalette.gold, width: 3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        _emblemAsset,
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'COW BULL QUEST',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ShareCardPalette.primaryText,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            topLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ShareCardPalette.cyan,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ShareCardPalette.secondaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Expanded(child: child),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: ShareCardPalette.divider),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      footerText,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ShareCardPalette.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
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

/// One compact detail row shared by [NormalWinShareCard] and
/// [DailyChallengeShareCard]: an icon paired with its own written label, so
/// the exported image never conveys meaning by icon alone.
class ShareCardDetailRow extends StatelessWidget {
  const ShareCardDetailRow({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = ShareCardPalette.cyan,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ShareCardPalette.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small gold-bordered pill badge, used for the difficulty badge and
/// similar short accents.
class ShareCardBadge extends StatelessWidget {
  const ShareCardBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: ShareCardPalette.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ShareCardPalette.gold, width: 1.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(
            color: ShareCardPalette.gold,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
