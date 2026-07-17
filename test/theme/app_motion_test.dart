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

  group('Milestone 15: new motion constants', () {
    test('entrance, shake, and emphasis stay within 150-350ms', () {
      for (final duration in [
        AppMotion.entrance,
        AppMotion.shake,
        AppMotion.emphasis,
      ]) {
        expect(duration.inMilliseconds, greaterThanOrEqualTo(150));
        expect(duration.inMilliseconds, lessThanOrEqualTo(350));
      }
    });

    testWidgets('durationFor zeroes entrance/shake/emphasis when animations '
        'are disabled', (tester) async {
      late Duration entrance;
      late Duration shake;
      late Duration emphasis;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                entrance = AppMotion.durationFor(context, AppMotion.entrance);
                shake = AppMotion.durationFor(context, AppMotion.shake);
                emphasis = AppMotion.durationFor(context, AppMotion.emphasis);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(entrance, Duration.zero);
      expect(shake, Duration.zero);
      expect(emphasis, Duration.zero);
    });
  });
}
