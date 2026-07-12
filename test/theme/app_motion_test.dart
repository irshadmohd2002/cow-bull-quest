import 'package:cowbullgame/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppMotion.durationFor', () {
    testWidgets('returns the given duration when animations are enabled', (
      tester,
    ) async {
      late Duration resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = AppMotion.durationFor(context, AppMotion.fast);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, AppMotion.fast);
    });

    testWidgets('returns Duration.zero when disableAnimations is true', (
      tester,
    ) async {
      late Duration resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                resolved = AppMotion.durationFor(context, AppMotion.standard);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolved, Duration.zero);
    });

    testWidgets('does not affect the standard duration when animations are '
        'enabled', (tester) async {
      late Duration resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = AppMotion.durationFor(context, AppMotion.standard);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, AppMotion.standard);
    });
  });
}
