import 'dart:io';

import 'package:cowbullgame/core/sharing/share_card_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _shareChannel = MethodChannel(
  'dev.fluttercommunity.plus/share',
);
const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> shareCalls;

  setUp(() {
    shareCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, (call) async {
          shareCalls.add(call);
          return 'dev.fluttercommunity.plus/share/success';
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
          if (call.method == 'getTemporaryDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
  });

  test('shareImage sends the descriptive filename, image/png MIME type, one '
      'file, and the exact caption as text', () async {
    const service = SharePlusShareCardService();
    final bytes = Uint8List.fromList(List.generate(16, (i) => i));

    await service.shareImage(
      bytes: bytes,
      fileName: 'cow-bull-quest-win.png',
      caption:
          'Cow Bull Quest\nSolved in 4/10 attempts.\nCan you solve it too?',
    );

    expect(shareCalls, hasLength(1));
    final args = Map<String, dynamic>.from(shareCalls.single.arguments as Map);

    final paths = List<String>.from(args['paths'] as List);
    expect(paths, hasLength(1));
    expect(paths.single.endsWith('cow-bull-quest-win.png'), isTrue);

    final mimeTypes = List<String>.from(args['mimeTypes'] as List);
    expect(mimeTypes, ['image/png']);

    expect(
      args['text'],
      'Cow Bull Quest\nSolved in 4/10 attempts.\nCan you solve it too?',
    );
  });
}
