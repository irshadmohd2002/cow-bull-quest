import 'dart:convert';
import 'dart:typed_data';

import 'package:cowbullgame/core/sharing/share_card_renderer.dart';
import 'package:flutter/widgets.dart';

/// A minimal, valid, decodable 1x1 transparent PNG — real image bytes rather
/// than arbitrary placeholder bytes, so a preview that actually decodes the
/// fake's output via [Image.memory] (as `ShareCardPreviewSheet` does) never
/// fails with an "Invalid image data" image-stream error in tests.
final Uint8List _tinyValidPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42Y'
  'AAAAASUVORK5CYII=',
);

/// In-memory [ShareCardRenderer] fake so widget tests never drive a real
/// offscreen widget-tree capture. Returns [bytesToReturn] (a tiny, valid,
/// decodable PNG by default) for every call, records every [card] rendered,
/// and can simulate a render failure or an in-flight delay.
class FakeShareCardRenderer implements ShareCardRenderer {
  /// Every rendered card, in call order.
  final List<Widget> renderedCards = [];

  /// The bytes returned by every call, unless [failWith] is set.
  Uint8List bytesToReturn = _tinyValidPng;

  /// If set, every call throws this error instead of returning bytes.
  Object? failWith;

  /// If set, `render` awaits this before completing — lets a test hold a
  /// render deterministically "in flight".
  Future<void>? delay;

  @override
  Future<Uint8List> render({
    required BuildContext context,
    required Widget card,
  }) async {
    final pending = delay;
    if (pending != null) await pending;
    renderedCards.add(card);
    final error = failWith;
    if (error != null) throw error;
    return bytesToReturn;
  }
}
