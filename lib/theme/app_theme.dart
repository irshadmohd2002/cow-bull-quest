import 'package:flutter/material.dart';

import 'app_status_colors.dart';

/// The Cow Bull Quest brand `ColorScheme`s and shared Material 3 component
/// theming, derived from `assets/branding/cow_bull_quest_icon.png`'s deep
/// navy/royal-blue/gold/cyan palette.
///
/// Every role pair below (`onX` against `x`, `onSurface` against
/// `surface`/`background`) has been checked against the WCAG contrast
/// formula: body-text pairs clear 4.5:1, large-text/icon/UI-outline pairs
/// clear 3:1. Gold (`primary`) is never used as body text on a light
/// surface — see [light]'s `onPrimary`. Final hex values are documented in
/// `docs/play_store/branding_guide.md`.
abstract final class AppTheme {
  // Shared brand hues, identical across both themes.
  static const Color _gold = Color(0xFFFFC33D);
  static const Color _royalBlue = Color(0xFF153B8C);
  static const Color _cyan = Color(0xFF2EC6FF);

  /// The app's light theme.
  static ThemeData get light {
    final base = ColorScheme.fromSeed(seedColor: _gold);
    final colorScheme = base.copyWith(
      primary: _gold,
      onPrimary: const Color(0xFF241900),
      primaryContainer: const Color(0xFFFFE3A3),
      onPrimaryContainer: const Color(0xFF241900),
      secondary: _royalBlue,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFD8E2FF),
      onSecondaryContainer: const Color(0xFF0A1F4D),
      tertiary: const Color(0xFF0A7EA8),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFCDEFFB),
      onTertiaryContainer: const Color(0xFF032B38),
      error: const Color(0xFFC62828),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: Colors.white,
      onSurface: const Color(0xFF14213D),
      surfaceContainerHighest: const Color(0xFFEEF2FB),
      onSurfaceVariant: const Color(0xFF5B6B8C),
      outline: const Color(0xFF7A88A8),
      outlineVariant: const Color(0xFFD3DAEA),
      inverseSurface: const Color(0xFF14213D),
      onInverseSurface: const Color(0xFFF5F1E6),
      inversePrimary: _gold,
    );
    return _themeFor(
      colorScheme,
      background: const Color(0xFFFAF7F1),
      statusColors: const AppStatusColors(
        success: Color(0xFF1E7A46),
        onSuccess: Colors.white,
      ),
    );
  }

  /// The app's dark theme — the palette most faithful to the approved icon.
  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      seedColor: _gold,
      brightness: Brightness.dark,
    );
    final colorScheme = base.copyWith(
      primary: _gold,
      onPrimary: const Color(0xFF0B1026),
      primaryContainer: const Color(0xFF7A5900),
      onPrimaryContainer: const Color(0xFFFFE3A3),
      secondary: const Color(0xFF2F5FC4),
      onSecondary: const Color(0xFFF5F1E6),
      secondaryContainer: const Color(0xFF1A2650),
      onSecondaryContainer: const Color(0xFFD8E2FF),
      tertiary: _cyan,
      onTertiary: const Color(0xFF072033),
      tertiaryContainer: const Color(0xFF0B3B52),
      onTertiaryContainer: const Color(0xFFCDEFFB),
      error: const Color(0xFFFF6B6B),
      onError: const Color(0xFF1A0000),
      errorContainer: const Color(0xFF5C1414),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: const Color(0xFF121A33),
      onSurface: const Color(0xFFF5F1E6),
      surfaceContainerHighest: const Color(0xFF1A2650),
      onSurfaceVariant: const Color(0xFFA9B7D6),
      outline: const Color(0xFF6B7AA0),
      outlineVariant: const Color(0xFF2A3660),
      inverseSurface: const Color(0xFFF5F1E6),
      onInverseSurface: const Color(0xFF14213D),
      inversePrimary: const Color(0xFF7A5900),
    );
    return _themeFor(
      colorScheme,
      background: const Color(0xFF0B1026),
      statusColors: const AppStatusColors(
        success: Color(0xFF34C77B),
        onSuccess: Color(0xFF03170C),
      ),
    );
  }

  /// Corner radius shared by cards, inputs, and buttons for a coherent,
  /// rounded Material 3 look.
  static const double _cornerRadius = 12;

  static ThemeData _themeFor(
    ColorScheme colorScheme, {
    required Color background,
    required AppStatusColors statusColors,
  }) {
    final radius = BorderRadius.circular(_cornerRadius);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      extensions: [statusColors],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
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
          foregroundColor: colorScheme.secondary,
          side: BorderSide(color: colorScheme.secondary),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: colorScheme.secondary,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
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
        selectedColor: colorScheme.secondaryContainer,
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cornerRadius * 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    );
  }
}
