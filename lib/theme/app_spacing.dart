/// Shared spacing constants for consistent gaps and padding across screens.
///
/// Values mirror the 4/8/12/16/24/32 increments already repeated as literal
/// `SizedBox`/`EdgeInsets` values across the `home`, `game`, `rules`, and
/// `settings` screens — collecting them here removes that duplication
/// without inventing a larger design-token system.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard outer padding for a scrollable screen body.
  static const double screenPadding = 24;
}
