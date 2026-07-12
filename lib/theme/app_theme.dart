import 'package:flutter/material.dart';

/// Shared Material 3 theming for the app.
///
/// Intentionally minimal for this milestone — a seed-color-derived
/// [ColorScheme] for light and dark, nothing more. Not a final brand
/// identity.
abstract final class AppTheme {
  static const Color _seedColor = Colors.indigo;

  /// The app's light theme.
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
  );

  /// The app's dark theme.
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
  );
}
