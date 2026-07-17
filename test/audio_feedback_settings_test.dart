import 'package:cowbullgame/audio_feedback_settings.dart';
import 'package:cowbullgame/core/persistence/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_preferences_store.dart';

void main() {
  group('AudioFeedbackSettings.load defaults', () {
    test('sound effects defaults to on when nothing is stored', () async {
      final settings = await AudioFeedbackSettings.load(FakePreferencesStore());
      expect(settings.soundEffectsEnabled, isTrue);
    });

    test('background music defaults to off when nothing is stored', () async {
      final settings = await AudioFeedbackSettings.load(FakePreferencesStore());
      expect(settings.musicEnabled, isFalse);
    });

    test('haptic feedback defaults to on when nothing is stored', () async {
      final settings = await AudioFeedbackSettings.load(FakePreferencesStore());
      expect(settings.hapticsEnabled, isTrue);
    });

    test('an unrecognized stored value falls back to that preference\'s '
        'default', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.soundEffectsEnabled: 'not-a-bool'},
      );
      final settings = await AudioFeedbackSettings.load(store);
      expect(settings.soundEffectsEnabled, isTrue);
    });

    test('a read failure on one key falls back to its default without '
        'affecting another key', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.musicEnabled: 'true'},
      )..failGetString = true;
      final settings = await AudioFeedbackSettings.load(store);
      expect(settings.soundEffectsEnabled, isTrue);
      expect(settings.musicEnabled, isFalse);
      expect(settings.hapticsEnabled, isTrue);
    });
  });

  group('AudioFeedbackSettings.load restores stored values', () {
    test('restores a stored sound-effects-disabled value', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.soundEffectsEnabled: 'false'},
      );
      final settings = await AudioFeedbackSettings.load(store);
      expect(settings.soundEffectsEnabled, isFalse);
    });

    test('restores a stored music-enabled value', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.musicEnabled: 'true'},
      );
      final settings = await AudioFeedbackSettings.load(store);
      expect(settings.musicEnabled, isTrue);
    });

    test('restores a stored haptics-disabled value', () async {
      final store = FakePreferencesStore(
        initialValues: {StorageKeys.hapticsEnabled: 'false'},
      );
      final settings = await AudioFeedbackSettings.load(store);
      expect(settings.hapticsEnabled, isFalse);
    });

    test('restores all three stored values together, simulating an app '
        'restart', () async {
      final store = FakePreferencesStore(
        initialValues: {
          StorageKeys.soundEffectsEnabled: 'false',
          StorageKeys.musicEnabled: 'true',
          StorageKeys.hapticsEnabled: 'false',
        },
      );
      final settings = await AudioFeedbackSettings.load(store);
      expect(settings.soundEffectsEnabled, isFalse);
      expect(settings.musicEnabled, isTrue);
      expect(settings.hapticsEnabled, isFalse);
    });
  });

  group('AudioFeedbackSettings setters', () {
    test('setSoundEffectsEnabled only writes its own key', () async {
      final store = FakePreferencesStore();
      final settings = AudioFeedbackSettings(store: store);

      settings.setSoundEffectsEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(store.setStringCalls, [StorageKeys.soundEffectsEnabled]);
    });

    test('setMusicEnabled only writes its own key', () async {
      final store = FakePreferencesStore();
      final settings = AudioFeedbackSettings(store: store);

      settings.setMusicEnabled(true);
      await Future<void>.delayed(Duration.zero);

      expect(store.setStringCalls, [StorageKeys.musicEnabled]);
    });

    test('setHapticsEnabled only writes its own key', () async {
      final store = FakePreferencesStore();
      final settings = AudioFeedbackSettings(store: store);

      settings.setHapticsEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(store.setStringCalls, [StorageKeys.hapticsEnabled]);
    });

    test('toggling one preference leaves the other two unchanged', () {
      final settings = AudioFeedbackSettings();

      settings.setMusicEnabled(true);

      expect(settings.musicEnabled, isTrue);
      expect(settings.soundEffectsEnabled, isTrue);
      expect(settings.hapticsEnabled, isTrue);
    });

    test('setting an already-current value does not notify or persist', () {
      final store = FakePreferencesStore();
      final settings = AudioFeedbackSettings(store: store);
      var notifyCount = 0;
      settings.addListener(() => notifyCount++);

      settings.setSoundEffectsEnabled(true); // already true

      expect(notifyCount, 0);
      expect(store.setStringCalls, isEmpty);
    });

    test('notifies listeners exactly once per accepted change', () {
      final settings = AudioFeedbackSettings();
      var notifyCount = 0;
      settings.addListener(() => notifyCount++);

      settings.setMusicEnabled(true);

      expect(notifyCount, 1);
    });

    test('a storage write failure does not throw and does not revert the '
        'in-memory value', () async {
      final store = FakePreferencesStore()..failSetString = true;
      final settings = AudioFeedbackSettings(store: store);

      expect(() => settings.setMusicEnabled(true), returnsNormally);
      expect(settings.musicEnabled, isTrue);

      // Allow the queued, failing persist to settle.
      await Future<void>.delayed(Duration.zero);
      expect(settings.debugLastPersistError, isNotNull);
    });
  });

  group('AudioFeedbackSettings independence from other app state', () {
    test(
      'does not read or write any storage key besides its own three',
      () async {
        final store = FakePreferencesStore();
        final settings = AudioFeedbackSettings(store: store);

        settings.setSoundEffectsEnabled(false);
        settings.setMusicEnabled(true);
        settings.setHapticsEnabled(false);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(store.setStringCalls, [
          StorageKeys.soundEffectsEnabled,
          StorageKeys.musicEnabled,
          StorageKeys.hapticsEnabled,
        ]);
      },
    );
  });
}
