import 'dart:typed_data';

import 'package:cowbullgame/core/sharing/share_card_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal fake [ShareCardService] used only to prove the abstraction
/// itself is easy to satisfy without any platform channel — the real
/// [SharePlusShareCardService] is exercised indirectly through
/// `ShareCardPreviewSheet` widget tests, which never touch a real platform
/// channel because they inject a fake there instead.
class _RecordingShareCardService implements ShareCardService {
  final List<({Uint8List bytes, String fileName, String caption})> calls = [];

  @override
  Future<void> shareImage({
    required Uint8List bytes,
    required String fileName,
    required String caption,
  }) async {
    calls.add((bytes: bytes, fileName: fileName, caption: caption));
  }
}

void main() {
  test(
    'shareImage records the exact bytes, filename, and caption given',
    () async {
      final service = _RecordingShareCardService();
      final bytes = Uint8List.fromList([1, 2, 3]);

      await service.shareImage(
        bytes: bytes,
        fileName: 'cow-bull-quest-win.png',
        caption: 'Cow Bull Quest',
      );

      expect(service.calls, hasLength(1));
      final call = service.calls.single;
      expect(call.bytes, bytes);
      expect(call.fileName, 'cow-bull-quest-win.png');
      expect(call.caption, 'Cow Bull Quest');
    },
  );
}
