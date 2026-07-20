import 'package:flutter/material.dart';

/// Fixed brand colors for exported share-card PNGs.
///
/// Deliberately **not** derived from `Theme.of(context)`: a share card must
/// "remain dark branded even when the user currently uses Light mode" (see
/// CLAUDE.md-adjacent milestone rule), so every share-card widget paints with
/// these hard-coded values instead of the ambient [ColorScheme] — the
/// exported image is therefore identical regardless of the app's active
/// theme. Values mirror [AppTheme.dark]'s own navy/blue/gold/cyan palette so
/// the card still feels like the rest of the app.
abstract final class ShareCardPalette {
  static const Color background = Color(0xFF071525);
  static const Color surface = Color(0xFF0D2138);
  static const Color elevatedSurface = Color(0xFF12304D);
  static const Color primaryBlue = Color(0xFF1769E0);
  static const Color royalBlue = Color(0xFF2457D6);
  static const Color gold = Color(0xFFD6A84B);
  static const Color cyan = Color(0xFF28C7D9);
  static const Color primaryText = Color(0xFFF5F7FB);
  static const Color secondaryText = Color(0xFFAFC2D8);
  static const Color divider = Color(0xFF24405F);
}
