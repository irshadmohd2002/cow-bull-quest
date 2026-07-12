import 'package:flutter/material.dart';

/// Shared Material 3 theming for the app.
///
/// A seed-color-derived [ColorScheme] for light and dark, plus component
/// themes (app bar, cards, buttons, inputs, segmented buttons, progress
/// indicators) so every screen gets consistent corner radii and contrast
/// without repeating `ButtonStyle`/`InputDecoration` literals per widget.
/// Built entirely from [ThemeData]/`ColorScheme.fromSeed` — no external
/// fonts or design packages. Not a final brand identity.
abstract final class AppTheme {
  static const Color _seedColor = Colors.indigo;

  /// Corner radius shared by cards, inputs, and buttons for a coherent,
  /// rounded Material 3 look.
  static const double _cornerRadius = 12;

  /// The app's light theme.
  static ThemeData get light =>
      _themeFor(ColorScheme.fromSeed(seedColor: _seedColor));

  /// The app's dark theme.
  static ThemeData get dark => _themeFor(
    ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
  );

  static ThemeData _themeFor(ColorScheme colorScheme) {
    final radius = BorderRadius.circular(_cornerRadius);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
