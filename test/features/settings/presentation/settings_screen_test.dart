import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    AppThemePreference themePreference = AppThemePreference.system,
    ValueChanged<AppThemePreference>? onThemePreferenceChanged,
  }) {
    return MaterialApp(
      home: SettingsScreen(
        themePreference: themePreference,
        onThemePreferenceChanged: onThemePreferenceChanged ?? (_) {},
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
}
