import 'package:cowbullgame/features/game/services/completion_id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecureRandomCompletionIdGenerator', () {
    const generator = SecureRandomCompletionIdGenerator();

    test(
      'generates a 32-character lowercase hexadecimal string (128 bits)',
      () {
        final id = generator.generate();
        expect(id.length, 32);
        expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
      },
    );

    test('does not repeat across many calls', () {
      final ids = {for (var i = 0; i < 500; i++) generator.generate()};
      expect(ids.length, 500);
    });
  });
}
