import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sharing/share_card_renderer.dart';
import '../../core/sharing/share_card_service.dart';
import '../../models/streak_share_data.dart';
import '../../services/share_caption_formatter.dart';
import 'share_card_preview_dialog.dart';
import 'streak_share_card.dart';

/// A compact icon button that opens the streak share-card preview.
///
/// Self-contained: owns its own "is a preview currently being opened" guard
/// (mirroring the same debounce pattern `GameScreen` uses for Share
/// Win/Challenge) so any screen can embed it directly — [HomeScreen]'s
/// streak row and [StreakSummaryCard] both do — without that screen having
/// to become stateful or duplicate this guard itself. Renders nothing at
/// all when [currentStreak] is `0`, satisfying "do not show or enable it
/// when current streak is 0" without the caller needing its own visibility
/// check.
class ShareStreakButton extends StatefulWidget {
  const ShareStreakButton({
    super.key,
    required this.currentStreak,
    required this.renderer,
    required this.service,
  });

  /// The player's current daily-play streak, in days.
  final int currentStreak;

  /// Renders the streak share card to PNG bytes.
  final ShareCardRenderer renderer;

  /// Hands the rendered card to the system share sheet.
  final ShareCardService service;

  @override
  State<ShareStreakButton> createState() => _ShareStreakButtonState();
}

class _ShareStreakButtonState extends State<ShareStreakButton> {
  static const ShareCaptionFormatter _captionFormatter =
      ShareCaptionFormatter();

  /// Set the instant a tap begins opening the preview sheet and cleared once
  /// it closes. Guards against a rapid double-tap opening two overlapping
  /// preview sheets.
  bool _opening = false;

  Future<void> _handleTap() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      // Captured once, here, before any `await` — a stable snapshot the
      // rendered card and its caption both use, so neither can observe a
      // streak value that changed partway through opening the sheet.
      final data = StreakShareData(currentStreak: widget.currentStreak);
      await showShareCardPreview(
        context: context,
        card: StreakShareCard(data: data),
        fileName: _fileNameFor(data.currentStreak),
        caption: _captionFormatter.streak(data),
        renderer: widget.renderer,
        service: widget.service,
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String _fileNameFor(int days) =>
      'cow-bull-quest-streak-$days-day${days == 1 ? '' : 's'}.png';

  @override
  Widget build(BuildContext context) {
    if (widget.currentStreak <= 0) return const SizedBox.shrink();
    return Semantics(
      container: true,
      button: true,
      label: 'Share streak',
      child: ExcludeSemantics(
        child: IconButton(
          onPressed: _opening ? null : () => unawaited(_handleTap()),
          tooltip: 'Share streak',
          icon: _opening
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share),
        ),
      ),
    );
  }
}
