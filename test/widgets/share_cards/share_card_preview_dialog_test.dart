import 'dart:async';

import 'package:cowbullgame/widgets/share_cards/share_card_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_share_card_renderer.dart';
import '../../support/fake_share_card_service.dart';

void main() {
  Widget hostWithOpenButton({
    required FakeShareCardRenderer renderer,
    required FakeShareCardService service,
    VoidCallback? onButtonTap,
    VoidCallback? onShared,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => unawaited(
                showShareCardPreview(
                  context: context,
                  card: const Text('card'),
                  fileName: 'cow-bull-quest-win.png',
                  caption: 'caption text',
                  renderer: renderer,
                  service: service,
                  onButtonTap: onButtonTap,
                  onShared: onShared,
                ),
              ),
              child: const Text('Open preview'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows a loading state while the card renders', (tester) async {
    final renderer = FakeShareCardRenderer()..delay = Completer<void>().future;
    final service = FakeShareCardService();
    await tester.pumpWidget(
      hostWithOpenButton(renderer: renderer, service: service),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pump();

    expect(find.text('Preparing share card...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('shows the rendered preview once generation completes', (
    tester,
  ) async {
    final renderer = FakeShareCardRenderer();
    final service = FakeShareCardService();
    await tester.pumpWidget(
      hostWithOpenButton(renderer: renderer, service: service),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(renderer.renderedCards, hasLength(1));
  });

  testWidgets('Cancel performs no share', (tester) async {
    final renderer = FakeShareCardRenderer();
    final service = FakeShareCardService();
    await tester.pumpWidget(
      hostWithOpenButton(renderer: renderer, service: service),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.calls, isEmpty);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('the close button performs no share and closes the sheet', (
    tester,
  ) async {
    final renderer = FakeShareCardRenderer();
    final service = FakeShareCardService();
    await tester.pumpWidget(
      hostWithOpenButton(renderer: renderer, service: service),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close preview'));
    await tester.pumpAndSettle();

    expect(service.calls, isEmpty);
    expect(find.text('Open preview'), findsOneWidget);
  });

  testWidgets('Share invokes the service exactly once with correct data', (
    tester,
  ) async {
    final renderer = FakeShareCardRenderer();
    final service = FakeShareCardService();
    var shared = 0;
    await tester.pumpWidget(
      hostWithOpenButton(
        renderer: renderer,
        service: service,
        onShared: () => shared++,
      ),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(service.calls, hasLength(1));
    final call = service.calls.single;
    expect(call.fileName, 'cow-bull-quest-win.png');
    expect(call.caption, 'caption text');
    expect(call.bytes, renderer.bytesToReturn);
    expect(shared, 1);
    // The sheet closes after a successful share.
    expect(find.byType(Image), findsNothing);
    // Share reuses the bytes already rendered for the preview rather than
    // triggering a second render.
    expect(renderer.renderedCards, hasLength(1));
  });

  testWidgets('rapid repeated taps on Share produce only one share call', (
    tester,
  ) async {
    final renderer = FakeShareCardRenderer();
    // A real platform share call always takes some real time; holding this
    // one open on a gate (rather than letting the fake resolve
    // immediately) keeps the share deterministically "in flight" across
    // both taps below, so the second tap genuinely exercises the
    // in-flight guard instead of racing Dart's microtask queue against an
    // instantly-resolving fake.
    final gate = Completer<void>();
    final service = FakeShareCardService()..delay = gate.future;
    await tester.pumpWidget(
      hostWithOpenButton(renderer: renderer, service: service),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.tap(find.text('Share'), warnIfMissed: false);
    gate.complete();
    await tester.pump();

    expect(service.calls, hasLength(1));
  });

  testWidgets('onButtonTap fires exactly once when the preview opens', (
    tester,
  ) async {
    final renderer = FakeShareCardRenderer();
    final service = FakeShareCardService();
    var taps = 0;
    await tester.pumpWidget(
      hostWithOpenButton(
        renderer: renderer,
        service: service,
        onButtonTap: () => taps++,
      ),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets(
    'a render failure shows the friendly message, not the raw error',
    (tester) async {
      final renderer = FakeShareCardRenderer()..failWith = Exception('boom');
      final service = FakeShareCardService();
      await tester.pumpWidget(
        hostWithOpenButton(renderer: renderer, service: service),
      );

      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();

      expect(find.text(shareCardFailureMessage), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      // Share is disabled when generation failed.
      final shareButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Share'),
      );
      expect(shareButton.onPressed, isNull);
    },
  );

  testWidgets('a share failure shows the friendly message, not the raw error', (
    tester,
  ) async {
    final renderer = FakeShareCardRenderer();
    final service = FakeShareCardService()..failWith = Exception('boom');
    await tester.pumpWidget(
      hostWithOpenButton(renderer: renderer, service: service),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text(shareCardFailureMessage), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
}
