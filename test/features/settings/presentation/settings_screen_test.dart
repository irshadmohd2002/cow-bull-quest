import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    AppThemePreference themePreference = AppThemePreference.system,
    ValueChanged<AppThemePreference>? onThemePreferenceChanged,
    VoidCallback? onOpenPrivacyPolicy,
  }) {
    return MaterialApp(
      home: SettingsScreen(
        themePreference: themePreference,
        onThemePreferenceChanged: onThemePreferenceChanged ?? (_) {},
        onOpenPrivacyPolicy: onOpenPrivacyPolicy,
      ),
    );
  }

  testWidgets('shows all three theme options', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('the current preference is selected', (tester) async {
    await tester.pumpWidget(
      buildSubject(themePreference: AppThemePreference.dark),
    );

    final group = tester.widget<RadioGroup<AppThemePreference>>(
      find.byType(RadioGroup<AppThemePreference>),
    );
    expect(group.groupValue, AppThemePreference.dark);
  });

  testWidgets('choosing a different option invokes the callback once', (
    tester,
  ) async {
    AppThemePreference? changedTo;
    var callCount = 0;
    await tester.pumpWidget(
      buildSubject(
        onThemePreferenceChanged: (preference) {
          changedTo = preference;
          callCount++;
        },
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(changedTo, AppThemePreference.dark);
    expect(callCount, 1);
  });

  testWidgets(
    'selecting the already-selected option does not invoke the callback '
    'again',
    (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        buildSubject(
          themePreference: AppThemePreference.light,
          onThemePreferenceChanged: (_) => callCount++,
        ),
      );

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(callCount, 0);
    },
  );

  testWidgets('the theme options have semantics', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.bySemanticsLabel('Follow system'), findsOneWidget);
    expect(find.bySemanticsLabel('Light'), findsOneWidget);
    expect(find.bySemanticsLabel('Dark'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not throw under large text scaling', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: buildSubject(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without exceptions when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: buildSubject(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Follow system'), findsOneWidget);
  });

  group('Privacy Policy row', () {
    testWidgets('appears with its title and supporting text', (tester) async {
      await tester.pumpWidget(buildSubject(onOpenPrivacyPolicy: () {}));

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(
        find.text('View how Cow Bull Quest handles local data.'),
        findsOneWidget,
      );
    });

    testWidgets('is disabled with "Available before public release." when '
        'onOpenPrivacyPolicy is null', (tester) async {
      await tester.pumpWidget(buildSubject());

      final tile = tester.widget<ListTile>(find.byType(ListTile).last);
      expect(tile.enabled, isFalse);
      expect(find.text('Available before public release.'), findsOneWidget);
    });

    testWidgets('does not invoke any callback while disabled', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      // No callback was supplied at all, so the only assertion possible is
      // that tapping a disabled row throws nothing and the row is still
      // present (i.e. no navigation or callback fired).
      expect(tester.takeException(), isNull);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('a real, non-null callback enables the row', (tester) async {
      await tester.pumpWidget(buildSubject(onOpenPrivacyPolicy: () {}));

      final tile = tester.widget<ListTile>(find.byType(ListTile).last);
      expect(tile.enabled, isTrue);
    });

    testWidgets('tapping the enabled row invokes the callback exactly once', (
      tester,
    ) async {
      var callCount = 0;
      await tester.pumpWidget(
        buildSubject(onOpenPrivacyPolicy: () => callCount++),
      );

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });

    testWidgets('has a semantics label reflecting the enabled state', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(onOpenPrivacyPolicy: () {}));

      expect(
        find.bySemanticsLabel(
          'Privacy Policy. View how Cow Bull Quest handles local data.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('has a semantics label reflecting the disabled state', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.bySemanticsLabel(
          'Privacy Policy. Available before public release.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not overflow on a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject(onOpenPrivacyPolicy: () {}));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('does not throw under 3x text scaling', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
          child: buildSubject(onOpenPrivacyPolicy: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  });
}
