import 'package:cowbullgame/features/game/presentation/widgets/guess_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    required TextEditingController controller,
    required FocusNode focusNode,
    int wordLength = 4,
    bool enabled = true,
    bool hasError = false,
    int rejectionSignal = 0,
    ValueChanged<String>? onSubmit,
    bool disableAnimations = false,
    double? width,
    TextScaler? textScaler,
  }) {
    Widget guessInput = GuessInput(
      controller: controller,
      focusNode: focusNode,
      wordLength: wordLength,
      enabled: enabled,
      hasError: hasError,
      rejectionSignal: rejectionSignal,
      onSubmit: onSubmit ?? (_) {},
    );
    if (textScaler != null) {
      guessInput = MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: guessInput,
      );
    }
    if (width != null) {
      guessInput = SizedBox(width: width, child: guessInput);
    }
    final child = MaterialApp(home: Scaffold(body: guessInput));
    if (!disableAnimations) return child;
    return MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: child,
    );
  }

  /// Material 3's default `TextField` font size in the pumped tree — what
  /// the field renders at when there's no need to shrink.
  double baseFontSizeOf(WidgetTester tester) => Theme.of(
    tester.element(find.byType(TextField)),
  ).textTheme.bodyLarge!.fontSize!;

  testWidgets('renders a text field and submit button', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildSubject(controller: controller, focusNode: focusNode),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('a rejection signal shakes the field without stealing focus', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'AB');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        hasError: true,
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        hasError: true,
        rejectionSignal: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final shakeFinder = find.byKey(
      const ValueKey('guess-input-shake-transform'),
    );
    final transform = tester.widget<Transform>(shakeFinder);
    // Mid-shake the field is offset from its resting position.
    expect(transform.transform.getTranslation().x, isNot(0.0));
    expect(focusNode.hasFocus, isTrue);
    expect(controller.text, 'AB');

    await tester.pumpAndSettle();
    final settledTransform = tester.widget<Transform>(shakeFinder);
    expect(settledTransform.transform.getTranslation().x, 0.0);
  });

  testWidgets('a repeated identical rejection signal shakes again rather '
      'than staying settled', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        hasError: true,
        rejectionSignal: 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        hasError: true,
        rejectionSignal: 2,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('guess-input-shake-transform')),
    );
    expect(transform.transform.getTranslation().x, isNot(0.0));

    await tester.pumpAndSettle();
  });

  testWidgets('does not shake when animations are disabled', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        hasError: true,
        disableAnimations: true,
      ),
    );

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        hasError: true,
        rejectionSignal: 1,
        disableAnimations: true,
      ),
    );
    await tester.pump();

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('guess-input-shake-transform')),
    );
    expect(transform.transform.getTranslation().x, 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping submit invokes onSubmit with the current text', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'race');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    String? submitted;

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        onSubmit: (value) => submitted = value,
      ),
    );

    await tester.tap(find.text('Submit'));
    expect(submitted, 'race');
  });

  testWidgets('a disabled field cannot be submitted', (tester) async {
    final controller = TextEditingController(text: 'race');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        enabled: false,
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('keeps the normal font size when width is ample', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildSubject(controller: controller, focusNode: focusNode, width: 800),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.fontSize, baseFontSizeOf(tester));
    expect(field.maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shrinks the guess text on a narrow width without overflowing', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildSubject(controller: controller, focusNode: focusNode, width: 150),
    );
    await tester.enterText(find.byType(TextField), 'race');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.fontSize, lessThan(baseFontSizeOf(tester)));
    expect(field.maxLines, 1);
    expect(controller.text, 'RACE');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shrinks the guess text when the text scale is increased', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    // A common narrow-phone content width (e.g. iPhone SE) — plenty of room
    // at the normal text scale, but not at 3x.
    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        width: 320,
        textScaler: const TextScaler.linear(3),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.fontSize, lessThan(baseFontSizeOf(tester)));
    expect(field.maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'does not overflow with both a narrow width and a large text scale',
    (tester) async {
      final controller = TextEditingController(text: 'RACE');
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Narrow enough to force the guess text to shrink, but still wide
      // enough for the (out-of-scope) Submit button beside it to fit — this
      // test is only about the guess input never overflowing or wrapping.
      await tester.pumpWidget(
        buildSubject(
          controller: controller,
          focusNode: focusNode,
          width: 260,
          textScaler: const TextScaler.linear(2),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style!.fontSize, lessThan(baseFontSizeOf(tester)));
      expect(field.maxLines, 1);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stays editable and functional on a narrow width', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    String? submitted;

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        width: 150,
        onSubmit: (value) => submitted = value,
      ),
    );

    await tester.enterText(find.byType(TextField), 'race');
    await tester.pump();
    expect(controller.text, 'RACE');
    expect(find.text('RACE'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'rac');
    await tester.pump();
    expect(controller.text, 'RAC');

    await tester.tap(find.text('Submit'));
    expect(submitted, 'RAC');
    expect(tester.takeException(), isNull);
  });

  testWidgets('still shakes on rejection at a narrow width', (tester) async {
    final controller = TextEditingController(text: 'AB');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        width: 150,
        hasError: true,
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        focusNode: focusNode,
        width: 150,
        hasError: true,
        rejectionSignal: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final shakeFinder = find.byKey(
      const ValueKey('guess-input-shake-transform'),
    );
    final transform = tester.widget<Transform>(shakeFinder);
    expect(transform.transform.getTranslation().x, isNot(0.0));
    expect(focusNode.hasFocus, isTrue);
    expect(controller.text, 'AB');
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    final settledTransform = tester.widget<Transform>(shakeFinder);
    expect(settledTransform.transform.getTranslation().x, 0.0);
  });
}
