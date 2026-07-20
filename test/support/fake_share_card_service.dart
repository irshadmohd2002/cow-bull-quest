import 'dart:typed_data';

import 'package:cowbullgame/core/sharing/share_card_service.dart';

/// In-memory [ShareCardService] fake so tests can assert exactly what was
/// shared, how many times, and force a simulated share failure — without
/// ever opening a real platform share sheet.
class FakeShareCardService implements ShareCardService {
  /// Every `shareImage` call, in call order.
  final List<({Uint8List bytes, String fileName, String caption})> calls = [];

  /// If set, every call throws this error instead of recording normally.
  Object? failWith;

  /// If set, `shareImage` awaits this before completing (and before
  /// recording into [calls]) instead of resolving immediately — lets a test
  /// hold a share deterministically "in flight".
  Future<void>? delay;

  @override
  Future<void> shareImage({
    required Uint8List bytes,
    required String fileName,
    required String caption,
  }) async {
    final pending = delay;
    if (pending != null) await pending;
    calls.add((bytes: bytes, fileName: fileName, caption: caption));
    final error = failWith;
    if (error != null) throw error;
  }
}
