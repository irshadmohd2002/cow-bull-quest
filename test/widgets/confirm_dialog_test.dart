import 'package:cowbullgame/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(void Function(BuildContext) onPressed) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => onPressed(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the given title and body', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        (context) => showConfirmDialog(
          context,
          title: 'Restart game?',
          body: 'Your current guesses will be cleared.',
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Restart game?'), findsOneWidget);
    expect(find.text('Your current guesses will be cleared.'), findsOneWidget);
  });

  testWidgets('uses the default Cancel/Confirm labels unless overridden', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        (context) => showConfirmDialog(context, title: 'Title', body: 'Body'),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('supports custom confirm/cancel labels', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        (context) => showConfirmDialog(
          context,
          title: 'Leave this game?',
          body: 'Your current guesses will be lost.',
          confirmLabel: 'Leave',
          cancelLabel: 'Keep playing',
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Keep playing'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
  });

  testWidgets('tapping Confirm resolves to true', (tester) async {
    bool? result;
    await tester.pumpWidget(
      buildSubject((context) async {
        result = await showConfirmDialog(context, title: 'Title', body: 'Body');
      }),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('tapping Cancel resolves to false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      buildSubject((context) async {
        result = await showConfirmDialog(context, title: 'Title', body: 'Body');
      }),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('dismissing via the scrim resolves to false, never null', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      buildSubject((context) async {
        result = await showConfirmDialog(context, title: 'Title', body: 'Body');
      }),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    // Tap the barrier, well outside the dialog content.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
