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
  }) {
    final child = MaterialApp(
      home: Scaffold(
        body: GuessInput(
          controller: controller,
          focusNode: focusNode,
          wordLength: wordLength,
          enabled: enabled,
          hasError: hasError,
          rejectionSignal: rejectionSignal,
          onSubmit: onSubmit ?? (_) {},
        ),
      ),
    );
    if (!disableAnimations) return child;
    return MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: child,
    );
  }

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
}
