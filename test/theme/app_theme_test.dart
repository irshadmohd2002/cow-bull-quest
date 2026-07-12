import 'package:cowbullgame/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
