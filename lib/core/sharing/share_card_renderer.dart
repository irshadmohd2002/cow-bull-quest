import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../widgets/share_cards/branded_share_card_frame.dart';

/// Rasterizes a share-card widget into a square PNG, entirely offscreen.
///
/// An abstraction over the actual rendering mechanism (rather than every
/// caller talking to [RepaintBoundary]/`dart:ui` directly) so
/// `ShareCardService` and its callers can be unit-tested against a fake that
/// returns canned bytes instead of driving a real widget-tree capture.
abstract class ShareCardRenderer {
  /// Renders [card] — expected to be a [BrandedShareCardFrame]-based widget
  /// laid out at [BrandedShareCardFrame.logicalSize] square — to PNG bytes at
  /// [pixelRatio] (3.0 by default, producing a 1080x1080 image from a 360
  /// logical-pixel card). [context] is used only to locate the app's root
  /// [Overlay]; nothing under it is read.
  ///
  /// Never mutates game state, statistics, streaks, or coins — this is a
  /// pure rendering operation.
  Future<Uint8List> render({
    required BuildContext context,
    required Widget card,
  });
}

/// The real [ShareCardRenderer]: mounts [card] into a [Positioned] entry on
/// the app's root [Overlay], positioned entirely outside the visible
/// viewport, so it builds/lays out/paints exactly like any other on-screen
/// widget — just never actually shown to the player — then captures it via
/// [RenderRepaintBoundary.toImage] and removes the entry again.
///
/// This never touches the visible screen the player is looking at (no
/// flicker, no visible flash) and never writes anything to disk itself —
/// [ShareCardService] is the layer that hands the resulting bytes to the
/// platform share sheet.
class OffscreenShareCardRenderer implements ShareCardRenderer {
  const OffscreenShareCardRenderer();

  @override
  Future<Uint8List> render({
    required BuildContext context,
    required Widget card,
    double pixelRatio = 3.0,
  }) async {
    // No `await` between resolving [context]-dependent state and using it —
    // this class is not a State and has no `mounted` to guard re-reading
    // [context] after a gap. Deliberately does *not* `precacheImage` the
    // branded emblem first: by the time any share action is reachable at
    // all (a completed game, a completed Daily Challenge, or a streak
    // greater than zero), the player has already visited Home at least
    // once, whose own hero card already loads this exact asset — so it is
    // already fully decoded and cached in practice. Awaiting a fresh decode
    // here would otherwise depend on real (non-frame-driven) asynchronous
    // work with no reliable way to bound it.
    final overlay = Overlay.of(context, rootOverlay: true);
    final boundaryKey = GlobalKey();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        // Far outside any real viewport, so this is never visible on
        // screen, while still being fully laid out, painted, and captured
        // like a normal widget — clipping applied by the Overlay's own
        // Stack only affects what is composited to the screen, not the
        // independent layer [RenderRepaintBoundary.toImage] reads from.
        left: -10000,
        top: -10000,
        child: IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: RepaintBoundary(key: boundaryKey, child: card),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      // Two frames: the first builds/lays out/paints the freshly-inserted
      // entry; the second guards against any single-frame settling (e.g. a
      // FittedBox's first layout pass) so the captured frame is never a
      // half-built one.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Share card failed to render: no render boundary.');
      }
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Share card failed to encode as PNG.');
        }
        return byteData.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      entry.remove();
    }
  }
}
