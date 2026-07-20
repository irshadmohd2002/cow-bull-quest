import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/sharing/share_card_renderer.dart';
import '../../core/sharing/share_card_service.dart';
import '../../theme/app_spacing.dart';

/// Shown whenever card generation or sharing fails. Never the raw
/// exception — sharing failure is not a debugging concern for the player.
const String shareCardFailureMessage =
    "Couldn't create the share card. Please try again.";

/// Opens a bottom sheet previewing [card] (rendered once, offscreen, via
/// [renderer]) before handing it to the system share sheet via [service].
///
/// [onButtonTap] fires once, synchronously, the moment this is called — the
/// same "play a button-activation sound" seam [GameScreen] already uses —
/// never on every rebuild. [card] should already be built from an immutable,
/// already-captured snapshot of whatever it displays (a completed game's
/// result, the official Daily Challenge result, or the current streak at the
/// moment the player tapped Share): this function renders it exactly once
/// and never re-reads live state afterward, so the exported PNG stays
/// internally consistent even if that live state changes while the sheet is
/// open.
Future<void> showShareCardPreview({
  required BuildContext context,
  required Widget card,
  required String fileName,
  required String caption,
  required ShareCardRenderer renderer,
  required ShareCardService service,
  VoidCallback? onButtonTap,
  VoidCallback? onShared,
}) {
  onButtonTap?.call();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ShareCardPreviewSheet(
      card: card,
      fileName: fileName,
      caption: caption,
      renderer: renderer,
      service: service,
      onShared: onShared,
    ),
  );
}

/// The bottom-sheet body [showShareCardPreview] opens: a loading state while
/// the card renders, the rendered preview once ready, and Share/Cancel
/// actions.
///
/// Renders [card] to PNG bytes exactly once, in [initState], and reuses
/// those same bytes both for the on-screen preview ([Image.memory]) and for
/// the eventual [ShareCardService.shareImage] call — never a second render.
/// Closing this sheet (Cancel, the close button, or a system back gesture)
/// never mutates any game state: it simply pops the route.
class ShareCardPreviewSheet extends StatefulWidget {
  const ShareCardPreviewSheet({
    super.key,
    required this.card,
    required this.fileName,
    required this.caption,
    required this.renderer,
    required this.service,
    this.onShared,
  });

  /// The share-card widget to render and preview.
  final Widget card;

  /// The descriptive filename the shared image is attached as.
  final String fileName;

  /// The short, spoiler-free caption sent alongside the image.
  final String caption;

  /// Renders [card] into PNG bytes.
  final ShareCardRenderer renderer;

  /// Hands the rendered bytes to the platform share sheet.
  final ShareCardService service;

  /// Called once sharing completes successfully — the seam a composition
  /// root can use for a light haptic (see the milestone's own "light haptic
  /// when the system share sheet successfully opens" rule), without this
  /// widget importing anything audio/haptic-related itself.
  final VoidCallback? onShared;

  @override
  State<ShareCardPreviewSheet> createState() => _ShareCardPreviewSheetState();
}

class _ShareCardPreviewSheetState extends State<ShareCardPreviewSheet> {
  Uint8List? _bytes;
  bool _rendering = true;
  bool _renderFailed = false;
  bool _sharing = false;
  String? _shareError;

  @override
  void initState() {
    super.initState();
    unawaited(_render());
  }

  Future<void> _render() async {
    try {
      final bytes = await widget.renderer.render(
        context: context,
        card: widget.card,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _rendering = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rendering = false;
        _renderFailed = true;
      });
    }
  }

  /// Shares the already-rendered [_bytes]. `_sharing` is set synchronously,
  /// before the `await`, so a rapid double-tap on Share cannot open two
  /// overlapping share sheets — the same pattern `GameScreen` uses for its
  /// own share/hint/restart actions.
  Future<void> _handleShare() async {
    final bytes = _bytes;
    if (_sharing || bytes == null) return;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      await widget.service.shareImage(
        bytes: bytes,
        fileName: widget.fileName,
        caption: widget.caption,
      );
      widget.onShared?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _sharing = false;
          _shareError = shareCardFailureMessage;
        });
      }
    }
  }

  void _handleClose() {
    if (_sharing) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canShare = !_rendering && !_renderFailed && !_sharing;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        // A scrollable, height-flexible container — rather than a plain
        // Column relying on the fixed-height preview square alone — so this
        // sheet degrades to scrolling instead of a hard RenderFlex overflow
        // on a short viewport or at a large text-scale factor.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Share preview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close preview',
                    child: ExcludeSemantics(
                      child: IconButton(
                        onPressed: _sharing ? null : _handleClose,
                        icon: const Icon(Icons.close),
                        tooltip: 'Close preview',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // A bounded square — rather than an AspectRatio sized purely
              // from the sheet's own width — so the preview never demands
              // more height than a short bottom sheet actually has to give.
              LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.maxWidth < 320
                      ? constraints.maxWidth
                      : 320.0;
                  return Center(
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: _PreviewBody(
                        rendering: _rendering,
                        failed: _renderFailed,
                        bytes: _bytes,
                      ),
                    ),
                  );
                },
              ),
              if (_shareError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  label: _shareError,
                  child: ExcludeSemantics(
                    child: Text(
                      _shareError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sharing ? null : _handleClose,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canShare ? _handleShare : null,
                      icon: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.rendering,
    required this.failed,
    required this.bytes,
  });

  final bool rendering;
  final bool failed;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (rendering) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Semantics(
            label: 'Preparing share card.',
            child: const ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.sm),
                  Text('Preparing share card...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final imageBytes = bytes;
    if (failed || imageBytes == null) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: shareCardFailureMessage,
            child: ExcludeSemantics(
              child: Text(
                shareCardFailureMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );
  }
}
