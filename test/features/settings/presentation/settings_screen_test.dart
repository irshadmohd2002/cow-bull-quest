import 'package:cowbullgame/app_settings.dart';
import 'package:cowbullgame/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    AppThemePreference themePreference = AppThemePreference.system,
    ValueChanged<AppThemePreference>? onThemePreferenceChanged,
    VoidCallback? onOpenPrivacyPolicy,
    bool soundEffectsEnabled = true,
    ValueChanged<bool>? onSoundEffectsChanged,
    bool musicEnabled = false,
    ValueChanged<bool>? onMusicChanged,
    bool hapticsEnabled = true,
    ValueChanged<bool>? onHapticsChanged,
    VoidCallback? onViewTutorial,
    VoidCallback? onResetLocalData,
  }) {
    return MaterialApp(
      home: SettingsScreen(
        themePreference: themePreference,
        onThemePreferenceChanged: onThemePreferenceChanged ?? (_) {},
        onOpenPrivacyPolicy: onOpenPrivacyPolicy,
        soundEffectsEnabled: soundEffectsEnabled,
        onSoundEffectsChanged: onSoundEffectsChanged ?? (_) {},
        musicEnabled: musicEnabled,
        onMusicChanged: onMusicChanged ?? (_) {},
        hapticsEnabled: hapticsEnabled,
        onHapticsChanged: onHapticsChanged ?? (_) {},
        onViewTutorial: onViewTutorial ?? () {},
        onResetLocalData: onResetLocalData,
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

      await tester.ensureVisible(find.text('Privacy Policy'));
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

      await tester.ensureVisible(find.text('Privacy Policy'));
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

  group('Audio & Feedback section', () {
    testWidgets('shows all three controls', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.widgetWithText(SwitchListTile, 'Sound effects'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SwitchListTile, 'Background music'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SwitchListTile, 'Haptic feedback'),
        findsOneWidget,
      );
    });

    testWidgets('shows each control\'s description', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.text('Plays interface and gameplay sound effects.'),
        findsOneWidget,
      );
      expect(
        find.text('Plays subtle music while using the app.'),
        findsOneWidget,
      );
      expect(
        find.text('Uses light vibration feedback for important actions.'),
        findsOneWidget,
      );
    });

    testWidgets('reflects the default switch states (sound on, music off, '
        'haptics on)', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          soundEffectsEnabled: true,
          musicEnabled: false,
          hapticsEnabled: true,
        ),
      );

      final tiles = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(tiles[0].value, isTrue); // Sound effects
      expect(tiles[1].value, isFalse); // Background music
      expect(tiles[2].value, isTrue); // Haptic feedback
    });

    testWidgets('toggling sound effects invokes only its own callback', (
      tester,
    ) async {
      bool? soundEffectsValue;
      var musicCallbackCount = 0;
      var hapticsCallbackCount = 0;
      await tester.pumpWidget(
        buildSubject(
          onSoundEffectsChanged: (value) => soundEffectsValue = value,
          onMusicChanged: (_) => musicCallbackCount++,
          onHapticsChanged: (_) => hapticsCallbackCount++,
        ),
      );

      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Sound effects'),
      );
      await tester.tap(find.widgetWithText(SwitchListTile, 'Sound effects'));
      await tester.pumpAndSettle();

      expect(soundEffectsValue, isFalse);
      expect(musicCallbackCount, 0);
      expect(hapticsCallbackCount, 0);
    });

    testWidgets('toggling background music invokes only its own callback', (
      tester,
    ) async {
      bool? musicValue;
      var soundEffectsCallbackCount = 0;
      var hapticsCallbackCount = 0;
      await tester.pumpWidget(
        buildSubject(
          onSoundEffectsChanged: (_) => soundEffectsCallbackCount++,
          onMusicChanged: (value) => musicValue = value,
          onHapticsChanged: (_) => hapticsCallbackCount++,
        ),
      );

      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Background music'),
      );
      await tester.tap(find.widgetWithText(SwitchListTile, 'Background music'));
      await tester.pumpAndSettle();

      expect(musicValue, isTrue);
      expect(soundEffectsCallbackCount, 0);
      expect(hapticsCallbackCount, 0);
    });

    testWidgets('toggling haptic feedback invokes only its own callback', (
      tester,
    ) async {
      bool? hapticsValue;
      var soundEffectsCallbackCount = 0;
      var musicCallbackCount = 0;
      await tester.pumpWidget(
        buildSubject(
          onSoundEffectsChanged: (_) => soundEffectsCallbackCount++,
          onMusicChanged: (_) => musicCallbackCount++,
          onHapticsChanged: (value) => hapticsValue = value,
        ),
      );

      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Haptic feedback'),
      );
      await tester.tap(find.widgetWithText(SwitchListTile, 'Haptic feedback'));
      await tester.pumpAndSettle();

      expect(hapticsValue, isFalse);
      expect(soundEffectsCallbackCount, 0);
      expect(musicCallbackCount, 0);
    });

    testWidgets('each control has a clear semantics label', (tester) async {
      await tester.pumpWidget(buildSubject());

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(
          RegExp('Sound effects.*sound effects', dotAll: true),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Background music.*music', dotAll: true)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Haptic feedback.*vibration', dotAll: true),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('does not overflow on a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithText(SwitchListTile, 'Sound effects'),
        findsOneWidget,
      );
    });

    testWidgets('does not overflow under large text scaling', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
          child: buildSubject(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithText(SwitchListTile, 'Sound effects'),
        findsOneWidget,
      );
    });
  });

  group('View Tutorial row', () {
    testWidgets('is always shown, with a supporting description', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('View Tutorial'), findsOneWidget);
      expect(
        find.text('Replaying it never changes your progress or settings.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping it invokes onViewTutorial exactly once', (
      tester,
    ) async {
      var callCount = 0;
      await tester.pumpWidget(buildSubject(onViewTutorial: () => callCount++));

      await tester.ensureVisible(find.text('View Tutorial'));
      await tester.tap(find.text('View Tutorial'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });
  });

  group('Reset local data row', () {
    testWidgets('is hidden when onResetLocalData is null', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Reset local data'), findsNothing);
    });

    testWidgets('appears when onResetLocalData is supplied', (tester) async {
      await tester.pumpWidget(buildSubject(onResetLocalData: () {}));
      expect(find.text('Reset local data'), findsOneWidget);
    });

    testWidgets('tapping it shows a confirmation dialog naming every '
        'cleared data category', (tester) async {
      await tester.pumpWidget(buildSubject(onResetLocalData: () {}));

      await tester.ensureVisible(find.text('Reset local data'));
      await tester.tap(find.text('Reset local data'));
      await tester.pumpAndSettle();

      expect(find.text('Reset local data?'), findsOneWidget);
      expect(find.textContaining('coins'), findsWidgets);
      expect(find.textContaining('statistics'), findsWidgets);
      expect(find.textContaining('streaks'), findsWidgets);
      expect(find.textContaining('Daily Challenge history'), findsWidgets);
      expect(find.textContaining('tutorial completion'), findsWidgets);
    });

    testWidgets('cancelling the dialog does not invoke onResetLocalData', (
      tester,
    ) async {
      var callCount = 0;
      await tester.pumpWidget(
        buildSubject(onResetLocalData: () => callCount++),
      );

      await tester.ensureVisible(find.text('Reset local data'));
      await tester.tap(find.text('Reset local data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(callCount, 0);
    });

    testWidgets('confirming the dialog invokes onResetLocalData exactly '
        'once', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        buildSubject(onResetLocalData: () => callCount++),
      );

      await tester.ensureVisible(find.text('Reset local data'));
      await tester.tap(find.text('Reset local data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });
  });
}
