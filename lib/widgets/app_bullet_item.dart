import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// One row of a bulleted list: a small decorative dot in a fixed-width
/// leading column, followed by the item's text.
///
/// Shared by onboarding and any equivalent Rules/Help bullet list (see
/// CLAUDE.md — presentation-only widgets used by 2+ features live under
/// `widgets/`). A [Row] with [CrossAxisAlignment.start] alone puts the dot
/// flush with the very top of the text's line box, not with the visible
/// glyphs on the first line — body text styles carry built-in leading space
/// above the cap height — so on a multi-line item the dot previously read
/// as floating above/detached from the first line. [_dotTopOffset] nudges
/// the dot down by that leading amount so it lines up with the first line
/// specifically; it is a small fixed nudge, not a computed vertical center
/// of the whole (possibly multi-line) paragraph, so the dot never drifts
/// back down toward the paragraph's middle as an item wraps to more lines.
class AppBulletItem extends StatelessWidget {
  const AppBulletItem({super.key, required this.text, this.style});

  /// The bullet's text; may wrap to multiple lines.
  final String text;

  /// Overrides the text style; defaults to [TextTheme.bodyLarge].
  final TextStyle? style;

  static const double _dotSize = 8;
  static const double _dotTopOffset = 6;
  static const double _leadingWidth = 20;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = style ?? Theme.of(context).textTheme.bodyLarge;

    // excludeSemantics: true so a screen reader announces [text] exactly
    // once, as one sentence — without it, the child Text below would also
    // contribute its own (identical) semantics node alongside this label.
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _leadingWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: _dotTopOffset),
              child: Icon(
                Icons.circle,
                size: _dotSize,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: textStyle)),
        ],
      ),
    );
  }
}
