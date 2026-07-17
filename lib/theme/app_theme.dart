import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_status_colors.dart';

/// The Cow Bull Quest brand `ColorScheme`s and shared Material 3 component
/// theming: a premium navy/blue/gold/cyan direction, distinct in both Dark
/// and Light mode from a generic Material app.
///
/// Role mapping (identical intent in both themes, different tones):
/// - `primary` — Primary blue: the app's one primary action color (Start
///   Game, Restart, focused input border, selected radio/segment).
/// - `secondary` — Royal blue: a second, distinct blue for secondary
///   actions/links (outlined/text buttons, Cows feedback, section
///   headings).
/// - `tertiary` — Cyan: secondary accents, hints, Bulls feedback, and
///   active/streak indicators.
/// - [AppStatusColors.success] — Gold: used sparingly, only for premium/
///   reward moments (the win outcome, the win-rate statistic) — never a
///   button or label color.
///
/// Every role pair below (`onX` against `x`, `onSurface` against
/// `surface`/background) has been checked against the WCAG contrast
/// formula: body-text pairs clear 4.5:1, large-text/icon/UI-outline pairs
/// clear 3:1 (see `test/theme/app_theme_test.dart`). Gold is never paired as
/// plain body text on either theme's surface — see the `success`-role tests.
abstract final class AppTheme {
  // Ink colors used only for text/icons drawn *on top of* a saturated brand
  // fill. Not part of the brand palette itself — chosen purely for
  // guaranteed contrast: white-ish text on the two blues (both dark/mid
  // toned), and a near-black ink on the two brighter hues (cyan, gold).
  static const Color _inkOnBlue = Colors.white;
  static const Color _inkOnBright = Color(0xFF041016);

  /// The app's light theme — the same brand family as [dark], not a
  /// generic white Material theme.
  static ThemeData get light {
    const background = Color(0xFFEEF4FB);
    const surface = Color(0xFFF8FBFF);
    const elevatedSurface = Color(0xFFE6F0FA);
    const primaryBlue = Color(0xFF195FC8);
    const royalBlue = Color(0xFF244FB5);
    const gold = Color(0xFFB98525);
    const cyan = Color(0xFF138FA0);
    const primaryText = Color(0xFF081B31);
    const secondaryText = Color(0xFF49657F);
    const divider = Color(0xFFC8D7E6);

    final base = ColorScheme.fromSeed(seedColor: primaryBlue);
    final colorScheme = base.copyWith(
      primary: primaryBlue,
      onPrimary: _inkOnBlue,
      primaryContainer: Color.lerp(primaryBlue, surface, 0.7),
      onPrimaryContainer: primaryText,
      secondary: royalBlue,
      onSecondary: _inkOnBlue,
      secondaryContainer: Color.lerp(royalBlue, surface, 0.7),
      onSecondaryContainer: primaryText,
      tertiary: cyan,
      onTertiary: _inkOnBright,
      tertiaryContainer: Color.lerp(cyan, surface, 0.75),
      onTertiaryContainer: primaryText,
      error: const Color(0xFFC62828),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: surface,
      onSurface: primaryText,
      surfaceContainerHighest: elevatedSurface,
      onSurfaceVariant: secondaryText,
      outline: secondaryText,
      outlineVariant: divider,
      // Mirrors the dark theme's surface/text/primary, so an inverse
      // element (e.g. a SnackBar) reads as "the other theme" rather than an
      // arbitrary unrelated color.
      inverseSurface: const Color(0xFF0D2138),
      onInverseSurface: const Color(0xFFF5F7FB),
      inversePrimary: const Color(0xFF1769E0),
    );
    return _themeFor(
      colorScheme,
      background: background,
      statusColors: const AppStatusColors(
        success: gold,
        onSuccess: _inkOnBright,
      ),
    );
  }

  /// The app's dark theme — Dark mode is the default for first-time
  /// installs (see `AppSettings`), so this is the palette most players see
  /// first.
  static ThemeData get dark {
    const background = Color(0xFF071525);
    const surface = Color(0xFF0D2138);
    const elevatedSurface = Color(0xFF12304D);
    const primaryBlue = Color(0xFF1769E0);
    const royalBlue = Color(0xFF2457D6);
    const gold = Color(0xFFD6A84B);
    const cyan = Color(0xFF28C7D9);
    const primaryText = Color(0xFFF5F7FB);
    const secondaryText = Color(0xFFAFC2D8);
    const divider = Color(0xFF24405F);

    final base = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
    );
    final colorScheme = base.copyWith(
      primary: primaryBlue,
      onPrimary: _inkOnBlue,
      primaryContainer: Color.lerp(primaryBlue, surface, 0.7),
      onPrimaryContainer: primaryText,
      secondary: royalBlue,
      onSecondary: _inkOnBlue,
      secondaryContainer: Color.lerp(royalBlue, surface, 0.7),
      onSecondaryContainer: primaryText,
      tertiary: cyan,
      onTertiary: _inkOnBright,
      tertiaryContainer: Color.lerp(cyan, surface, 0.75),
      onTertiaryContainer: primaryText,
      error: const Color(0xFFFF6B6B),
      onError: const Color(0xFF1A0000),
      errorContainer: const Color(0xFF5C1414),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: surface,
      onSurface: primaryText,
      surfaceContainerHighest: elevatedSurface,
      onSurfaceVariant: secondaryText,
      outline: secondaryText,
      outlineVariant: divider,
      // Mirrors the light theme's surface/text/primary — see [light].
      inverseSurface: const Color(0xFFF8FBFF),
      onInverseSurface: const Color(0xFF081B31),
      inversePrimary: const Color(0xFF195FC8),
    );
    return _themeFor(
      colorScheme,
      background: background,
      statusColors: const AppStatusColors(
        success: gold,
        onSuccess: _inkOnBright,
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
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      extensions: [statusColors],
      appBarTheme: AppBarTheme(
        // Matches the scaffold background (rather than colorScheme.surface)
        // so the AppBar blends into the screen instead of showing a hard
        // edge; elevation/tint are zeroed so scrolling content can't
        // reintroduce that seam under the AppBar.
        backgroundColor: background,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Every screen has an AppBar, so this is the single place that
        // drives the status bar and Android navigation bar to match the
        // active theme rather than defaulting to the platform's own style.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarBrightness: Brightness.dark,
                systemNavigationBarColor: background,
                systemNavigationBarIconBrightness: Brightness.light,
                systemNavigationBarDividerColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                statusBarBrightness: Brightness.light,
                systemNavigationBarColor: background,
                systemNavigationBarIconBrightness: Brightness.dark,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
      ),
      cardTheme: CardThemeData(
        // Explicit, rather than left to Material 3's default
        // surfaceContainerLow: that role is never overridden below (only
        // surfaceContainerHighest is, to keep the override list small), so
        // it would otherwise fall back to a tone derived straight from the
        // primary seed color instead of the brand's own elevated-surface
        // tone.
        color: colorScheme.surfaceContainerHighest,
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
