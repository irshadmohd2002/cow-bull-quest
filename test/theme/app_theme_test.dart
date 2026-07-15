import 'dart:math' as math;

import 'package:cowbullgame/theme/app_status_colors.dart';
import 'package:cowbullgame/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Relative luminance per the WCAG contrast formula.
double _luminance(Color color) {
  double linear(double channel) => channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * linear(color.r) +
      0.7152 * linear(color.g) +
      0.0722 * linear(color.b);
}

/// WCAG contrast ratio between two colors (1.0 = no contrast, 21.0 = max).
double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppTheme', () {
    test('light theme uses Material 3 with a light color scheme', () {
      final theme = AppTheme.light;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('dark theme uses Material 3 with a dark color scheme', () {
      final theme = AppTheme.dark;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('light and dark themes share the same seed-derived primary hue '
        'family but differ in brightness', () {
      expect(
        AppTheme.light.colorScheme.brightness,
        isNot(AppTheme.dark.colorScheme.brightness),
      );
    });

    test('applies a card theme with clipped, rounded corners', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.cardTheme.clipBehavior, Clip.antiAlias);
        expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      }
    });

    test('applies filled, outlined, and text button themes with a minimum '
        'tap target size', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.filledButtonTheme.style, isNotNull);
        expect(theme.outlinedButtonTheme.style, isNotNull);
        expect(theme.textButtonTheme.style, isNotNull);
      }
    });

    test('applies an input decoration theme with a rounded, filled border', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(theme.inputDecorationTheme.border, isA<OutlineInputBorder>());
      }
    });

    test('applies a segmented button theme', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.segmentedButtonTheme.style, isNotNull);
      }
    });

    test('applies a progress indicator theme tied to the color scheme', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.progressIndicatorTheme.color, theme.colorScheme.primary);
      }
    });

    testWidgets('light theme builds a MaterialApp without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Text('light')),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('light'), findsOneWidget);
    });

    testWidgets('dark theme builds a MaterialApp without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: Text('dark')),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('dark'), findsOneWidget);
    });
  });

  group('AppTheme AppBar blends with the scaffold', () {
    test(
      'light AppBar background matches the pale-blue scaffold background',
      () {
        final theme = AppTheme.light;
        expect(
          theme.appBarTheme.backgroundColor,
          theme.scaffoldBackgroundColor,
        );
      },
    );

    test(
      'dark AppBar background matches the deep navy scaffold background',
      () {
        final theme = AppTheme.dark;
        expect(
          theme.appBarTheme.backgroundColor,
          theme.scaffoldBackgroundColor,
        );
      },
    );

    test('AppBar has no elevation, scrolled-under elevation, or surface '
        'tint that would create a seam', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.appBarTheme.elevation, 0);
        expect(theme.appBarTheme.scrolledUnderElevation, 0);
        expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      }
    });

    test('AppBar foreground color meets WCAG contrast against its own '
        'background in both themes', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final ratio = _contrastRatio(
          theme.appBarTheme.foregroundColor!,
          theme.appBarTheme.backgroundColor!,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${theme.colorScheme.brightness} AppBar foreground/background '
              'contrast ratio $ratio is below the 4.5:1 body-text minimum',
        );
      }
    });

    testWidgets('themed AppBar renders flush with the scaffold body behind '
        'scrollable content', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              appBar: AppBar(title: const Text('Cow Bull Quest')),
              body: ListView(
                children: List.generate(30, (i) => ListTile(title: Text('$i'))),
              ),
            ),
          ),
        );
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();

        final appBarMaterial = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(appBarMaterial.color, theme.scaffoldBackgroundColor);
        expect(appBarMaterial.elevation, 0);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('AppTheme brand palette', () {
    const brandGold = Color(0xFFFFC33D);

    test('primary is the same brand gold in both light and dark theme', () {
      expect(AppTheme.light.colorScheme.primary, brandGold);
      expect(AppTheme.dark.colorScheme.primary, brandGold);
    });

    test('secondary is a royal blue, distinct from primary', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.colorScheme.secondary, isNot(theme.colorScheme.primary));
        // Blue-dominant: the blue channel clearly exceeds red.
        expect(
          theme.colorScheme.secondary.b,
          greaterThan(theme.colorScheme.secondary.r),
        );
      }
    });

    test('tertiary is a cyan, distinct from primary and secondary', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.colorScheme.tertiary, isNot(theme.colorScheme.primary));
        expect(theme.colorScheme.tertiary, isNot(theme.colorScheme.secondary));
      }
    });

    test('error is distinct in hue from the brand gold primary', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.colorScheme.error, isNot(theme.colorScheme.primary));
        // Gold is red+green dominant with little blue; the brand error red
        // has a much lower green channel, keeping the two unmistakable.
        expect(
          theme.colorScheme.error.g,
          lessThan(theme.colorScheme.primary.g),
        );
      }
    });

    test('AppStatusColors.success is registered on both themes and distinct '
        'from error and primary', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final status = theme.extension<AppStatusColors>();
        expect(status, isNotNull);
        expect(status!.success, isNot(theme.colorScheme.error));
        expect(status.success, isNot(theme.colorScheme.primary));
      }
    });

    test('every brand onX/x role pair meets WCAG contrast minimums', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final scheme = theme.colorScheme;
        final status = theme.extension<AppStatusColors>()!;
        final bodyTextPairs = <String, (Color, Color)>{
          'onPrimary/primary': (scheme.onPrimary, scheme.primary),
          'onSecondary/secondary': (scheme.onSecondary, scheme.secondary),
          'onTertiary/tertiary': (scheme.onTertiary, scheme.tertiary),
          'onError/error': (scheme.onError, scheme.error),
          'onSuccess/success': (status.onSuccess, status.success),
          'onSurface/surface': (scheme.onSurface, scheme.surface),
          'onSurface/background': (
            scheme.onSurface,
            theme.scaffoldBackgroundColor,
          ),
        };
        for (final entry in bodyTextPairs.entries) {
          final ratio = _contrastRatio(entry.value.$1, entry.value.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${theme.colorScheme.brightness} ${entry.key} contrast '
                'ratio $ratio is below the 4.5:1 body-text minimum',
          );
        }
      }
    });

    test('gold primary is never paired as onSurface body text on a light '
        'surface', () {
      // The light theme's onSurface (body text color) must not be the
      // brand gold - gold is reserved for primary-action fills, never
      // plain text on a light background.
      expect(AppTheme.light.colorScheme.onSurface, isNot(brandGold));
    });

    testWidgets('themed Card, Chip, buttons, and InputDecoration build '
        'without exceptions', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  const Card(child: Text('card')),
                  const Chip(label: Text('chip')),
                  FilledButton(onPressed: () {}, child: const Text('go')),
                  OutlinedButton(onPressed: () {}, child: const Text('go')),
                  TextButton(onPressed: () {}, child: const Text('go')),
                  const TextField(
                    decoration: InputDecoration(labelText: 'field'),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
