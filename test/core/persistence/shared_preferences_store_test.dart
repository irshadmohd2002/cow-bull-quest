import 'package:cowbullgame/core/persistence/shared_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesStore', () {
    test('getString returns null when nothing is stored', () async {
      const store = SharedPreferencesStore();
      expect(await store.getString('missing'), isNull);
    });

    test('setString then getString round-trips the value', () async {
      const store = SharedPreferencesStore();
      await store.setString('key', 'value');
      expect(await store.getString('key'), 'value');
    });

    test('remove deletes a previously stored value', () async {
      const store = SharedPreferencesStore();
      await store.setString('key', 'value');
      await store.remove('key');
      expect(await store.getString('key'), isNull);
    });

    test('remove does nothing when the key is absent', () async {
      const store = SharedPreferencesStore();
      await expectLater(store.remove('missing'), completes);
    });
  });
}
