import 'package:cowbullgame/theme/app_theme.dart';
import 'package:cowbullgame/widgets/app_bullet_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(
    String text, {
    double width = 400,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AppBulletItem(text: text),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the bullet text', (tester) async {
    await tester.pumpWidget(buildSubject('Guess the hidden word.'));
    expect(find.text('Guess the hidden word.'), findsOneWidget);
  });

  testWidgets('exposes exactly one semantics label for the sentence, with '
      'the decorative dot excluded (so it never gets announced separately)', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject('Guess the hidden word.'));

    expect(find.bySemanticsLabel('Guess the hidden word.'), findsOneWidget);
  });

  testWidgets(
    'on a one-line item, the bullet dot sits near the top of the text, not '
    'centered against it',
    (tester) async {
      await tester.pumpWidget(buildSubject('Short bullet.'));

      final dotRect = tester.getRect(find.byIcon(Icons.circle));
      final textRect = tester.getRect(find.text('Short bullet.'));

      expect(dotRect.top, greaterThan(textRect.top));
      expect(dotRect.center.dy, lessThan(textRect.center.dy));
    },
  );

  testWidgets(
    'on a multi-line item, the bullet dot aligns with the first line — its '
    'vertical center stays above the whole paragraph\'s midpoint, not '
    'centered against it',
    (tester) async {
      const longBullet =
          'This is a deliberately long bullet sentence that will wrap onto '
          'several lines once it is squeezed into a narrow column width.';
      await tester.pumpWidget(buildSubject(longBullet, width: 220));

      final dotRect = tester.getRect(find.byIcon(Icons.circle));
      final textRect = tester.getRect(find.text(longBullet));

      // A wrapped, multi-line paragraph is taller than one line.
      expect(textRect.height, greaterThan(30));
      expect(dotRect.center.dy, lessThan(textRect.center.dy));
    },
  );

  testWidgets(
    'continuation lines align with the text start, not under the bullet: '
    'the text block begins after the fixed leading (dot + spacing) area',
    (tester) async {
      const longBullet =
          'This is a deliberately long bullet sentence that will wrap onto '
          'several lines once it is squeezed into a narrow column width.';
      await tester.pumpWidget(buildSubject(longBullet, width: 220));

      final dotRect = tester.getRect(find.byIcon(Icons.circle));
      final textRect = tester.getRect(find.text(longBullet));

      expect(textRect.left, greaterThan(dotRect.right));
    },
  );

  testWidgets('does not overflow at a large text scale', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        'This is a deliberately long bullet sentence that will wrap.',
        width: 220,
        textScaler: const TextScaler.linear(2.5),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without exceptions in dark and light themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: AppBulletItem(text: 'Themed bullet text.'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
