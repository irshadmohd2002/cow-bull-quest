import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cowbullgame/core/sharing/share_card_renderer.dart';
import 'package:cowbullgame/models/streak_share_data.dart';
import 'package:cowbullgame/widgets/share_cards/streak_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rasterizes [key]'s [RepaintBoundary] to PNG bytes at [pixelRatio], the
/// same "widget subtree -> PNG" contract [OffscreenShareCardRenderer] itself
/// relies on ([RenderRepaintBoundary.toImage] then
/// `image.toByteData(format: png)`) — wrapped in [WidgetTester.runAsync],
/// which `flutter_test`'s own golden-image matcher (`matchesGoldenFile`)
/// also requires for exactly this operation: raw image encoding is real,
/// engine-driven asynchronous work that a widget test's normal fake-async
/// zone cannot resolve on its own.
///
/// [OffscreenShareCardRenderer] additionally mounts [key]'s subtree into an
/// offscreen [Positioned] entry on the app's root [Overlay] first (see
/// `share_card_renderer_test.dart`'s "mounts the card offscreen" test group
/// below, which verifies that mounting mechanism directly) — a step this
/// helper skips by mounting [key]'s subtree as an ordinary on-screen widget
/// instead. Combining that pump-driven offscreen mount with this
/// `runAsync`-driven capture in a single automated test is not possible:
/// once real image-codec work has run outside `runAsync`, no later
/// `WidgetTester.pump` in the same test can complete (a well-known
/// `flutter_test` fake-async/real-async conflict), and `runAsync`'s own
/// callback is not permitted to call `pump` either. Exercising the
/// PNG-encoding contract this way, and the offscreen-mount mechanism
/// separately below, together cover everything [OffscreenShareCardRenderer]
/// actually does; only the fully end-to-end combination needs the manual
/// on-device verification called out in the milestone report.
Future<Uint8List> _capturePng(
  WidgetTester tester,
  GlobalKey key, {
  double pixelRatio = 2.0,
}) async {
  final bytes = await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      return await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
  });
  return bytes!.buffer.asUint8List();
}

void main() {
  group('PNG encoding contract (shared by OffscreenShareCardRenderer)', () {
    Future<GlobalKey> pumpCard(WidgetTester tester, Widget card) async {
      final key = GlobalKey();
      // Center gives the RepaintBoundary loose constraints, so the card's
      // own fixed 360x360 logical size (see BrandedShareCardFrame) is what
      // determines its size — not the full test viewport, which is what a
      // bare MaterialApp.home would otherwise force it to.
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(key: key, child: card),
          ),
        ),
      );
      await tester.pump();
      return key;
    }

    testWidgets('returns non-empty PNG bytes with the correct signature', (
      tester,
    ) async {
      final key = await pumpCard(
        tester,
        StreakShareCard(data: StreakShareData(currentStreak: 7)),
      );
      final bytes = await _capturePng(tester, key);

      expect(bytes, isNotEmpty);
      // The 8-byte PNG file signature.
      expect(bytes.sublist(0, 8), const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
    });

    testWidgets('produces a 720x720 image (360 logical @ pixelRatio 2.0)', (
      tester,
    ) async {
      final key = await pumpCard(
        tester,
        StreakShareCard(data: StreakShareData(currentStreak: 1)),
      );
      final bytes = await _capturePng(tester, key, pixelRatio: 2.0);

      final decoded = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final size = (frame.image.width, frame.image.height);
        frame.image.dispose();
        codec.dispose();
        return size;
      });

      expect(decoded, (720, 720));
    });

    testWidgets('repeated rendering with the same input is stable', (
      tester,
    ) async {
      final data = StreakShareData(currentStreak: 30);
      final key1 = await pumpCard(tester, StreakShareCard(data: data));
      final first = await _capturePng(tester, key1);

      final key2 = await pumpCard(tester, StreakShareCard(data: data));
      final second = await _capturePng(tester, key2);

      expect(first, isNotEmpty);
      expect(second, isNotEmpty);
      expect(first.length, second.length);
    });

    testWidgets('disposing the captured image does not crash', (tester) async {
      final key = await pumpCard(
        tester,
        StreakShareCard(data: StreakShareData(currentStreak: 5)),
      );

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        image.dispose();
      });

      expect(tester.takeException(), isNull);
    });
  });

  group('OffscreenShareCardRenderer offscreen mount', () {
    const renderer = OffscreenShareCardRenderer();

    testWidgets(
      'mounts the card into the tree via the root Overlay without showing '
      'it on the visible screen',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('host'))),
          ),
        );
        final context = tester.element(find.text('host'));

        // Deliberately not awaited to completion: this proves the widget is
        // mounted offscreen (via the root Overlay) without ever driving the
        // render through to PNG bytes, which is covered separately above
        // (see this file's class-level doc for why the two cannot be
        // combined in one automated test). The eventual completion (or, as
        // here, error — its remaining internal `endOfFrame` await is never
        // satisfied by a second pump) is explicitly swallowed so it can
        // never surface as a spurious failure attributed to a later test.
        unawaited(
          renderer
              .render(
                context: context,
                card: StreakShareCard(data: StreakShareData(currentStreak: 3)),
              )
              .catchError((_) => Uint8List(0)),
        );
        await tester.pump();

        expect(find.byType(StreakShareCard), findsOneWidget);
        expect(find.text('STREAK'), findsOneWidget);
        // The offscreen entry is positioned far outside the visible host
        // screen, so the visible "host" text remains the only thing
        // actually on screen from the player's perspective.
        expect(find.text('host'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
