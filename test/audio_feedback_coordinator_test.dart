import 'package:cowbullgame/audio_feedback_coordinator.dart';
import 'package:cowbullgame/audio_feedback_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_audio_service.dart';
import 'support/fake_haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AudioFeedbackCoordinator buildSubject({
    required FakeAudioService audio,
    required FakeHapticService haptics,
    required AudioFeedbackSettings settings,
  }) => AudioFeedbackCoordinator(
    audioService: audio,
    hapticService: haptics,
    settings: settings,
  );

  group('sound effects gating', () {
    test('disabled sound effects suppress every SFX call', () {
      final audio = FakeAudioService();
      final haptics = FakeHapticService();
      final settings = AudioFeedbackSettings(initialSoundEffectsEnabled: false);
      final coordinator = buildSubject(
        audio: audio,
        haptics: haptics,
        settings: settings,
      );
      addTearDown(coordinator.dispose);

      coordinator.playButtonTap();
      coordinator.onInvalidGuess();
      coordinator.onHintRevealed(paid: false);
      coordinator.onGameWon();
      coordinator.onGameLost();

      expect(audio.calls, isEmpty);
    });

    test('enabled sound effects call the correct effect exactly once', () {
      final audio = FakeAudioService();
      final haptics = FakeHapticService();
      final settings = AudioFeedbackSettings();
      final coordinator = buildSubject(
        audio: audio,
        haptics: haptics,
        settings: settings,
      );
      addTearDown(coordinator.dispose);

      coordinator.playButtonTap();

      expect(audio.calls, ['playButtonTap']);
    });

    test('onInvalidGuess plays the invalid-guess effect once', () {
      final audio = FakeAudioService();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onInvalidGuess();

      expect(audio.calls, ['playInvalidGuess']);
    });

    test('onGameWon plays the win effect once', () {
      final audio = FakeAudioService();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onGameWon();

      expect(audio.calls, ['playWin']);
    });

    test('onGameLost plays the loss effect once', () {
      final audio = FakeAudioService();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onGameLost();

      expect(audio.calls, ['playLoss']);
    });

    test('a free hint plays only hint-used, never coin-spent', () {
      final audio = FakeAudioService();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onHintRevealed(paid: false);

      expect(audio.calls, ['playHintUsed']);
    });

    test(
      'a paid hint plays coin-spent then hint-used, in that order',
      () async {
        final audio = FakeAudioService();
        final coordinator = buildSubject(
          audio: audio,
          haptics: FakeHapticService(),
          settings: AudioFeedbackSettings(),
        );
        addTearDown(coordinator.dispose);

        coordinator.onHintRevealed(paid: true);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(audio.calls, ['playCoinSpent', 'playHintUsed']);
      },
    );
  });

  group('haptics gating', () {
    test('disabled haptics suppress every haptic call', () {
      final haptics = FakeHapticService();
      final coordinator = buildSubject(
        audio: FakeAudioService(),
        haptics: haptics,
        settings: AudioFeedbackSettings(initialHapticsEnabled: false),
      );
      addTearDown(coordinator.dispose);

      coordinator.onDifficultySelected();
      coordinator.onValidGuess();
      coordinator.onInvalidGuess();
      coordinator.onHintRevealed(paid: true);
      coordinator.onGameWon();
      coordinator.onGameLost();

      expect(haptics.calls, isEmpty);
    });

    test('onDifficultySelected triggers selectionClick', () {
      final haptics = FakeHapticService();
      final coordinator = buildSubject(
        audio: FakeAudioService(),
        haptics: haptics,
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onDifficultySelected();

      expect(haptics.calls, ['selectionClick']);
    });

    test('onValidGuess triggers lightImpact', () {
      final haptics = FakeHapticService();
      final coordinator = buildSubject(
        audio: FakeAudioService(),
        haptics: haptics,
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onValidGuess();

      expect(haptics.calls, ['lightImpact']);
    });

    test('onInvalidGuess triggers warning', () {
      final haptics = FakeHapticService();
      final coordinator = buildSubject(
        audio: FakeAudioService(),
        haptics: haptics,
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onInvalidGuess();

      expect(haptics.calls, ['warning']);
    });

    test('a free hint triggers lightImpact', () {
      final haptics = FakeHapticService();
      final coordinator = buildSubject(
        audio: FakeAudioService(),
        haptics: haptics,
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onHintRevealed(paid: false);

      expect(haptics.calls, ['lightImpact']);
    });

    test('a paid hint triggers mediumImpact', () {
      final haptics = FakeHapticService();
      final coordinator = buildSubject(
        audio: FakeAudioService(),
        haptics: haptics,
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onHintRevealed(paid: true);

      expect(haptics.calls, ['mediumImpact']);
    });

    test('onGameWon triggers success', () {
      final haptics = FakeHapticService();
      final coordinator = buildSubject(
        audio: FakeAudioService(),
        haptics: haptics,
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onGameWon();

      expect(haptics.calls, ['success']);
    });

    test('onGameLost triggers mediumImpact', () {
      final haptics = FakeHapticService();
      final coordinator = buildSubject(
        audio: FakeAudioService(),
        haptics: haptics,
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.onGameLost();

      expect(haptics.calls, ['mediumImpact']);
    });
  });

  group('background music lifecycle', () {
    test('music starts disabled by default, so construction never starts '
        'the loop', () {
      final audio = FakeAudioService();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      expect(audio.calls, isEmpty);
    });

    test('construction with music already enabled starts exactly one loop', () {
      final audio = FakeAudioService();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(initialMusicEnabled: true),
      );
      addTearDown(coordinator.dispose);

      expect(audio.calls, ['startMusic']);
    });

    test('enabling music after construction starts exactly one loop', () {
      final audio = FakeAudioService();
      final settings = AudioFeedbackSettings();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: settings,
      );
      addTearDown(coordinator.dispose);

      settings.setMusicEnabled(true);

      expect(audio.calls, ['startMusic']);
    });

    test('re-enabling an already-enabled value does not start a second '
        'loop (no duplicate loops from repeated notifications)', () {
      final audio = FakeAudioService();
      final settings = AudioFeedbackSettings();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: settings,
      );
      addTearDown(coordinator.dispose);

      settings.setMusicEnabled(true);
      settings.setMusicEnabled(true); // no-op: already true

      expect(audio.calls.where((call) => call == 'startMusic').length, 1);
    });

    test('disabling music stops it promptly', () {
      final audio = FakeAudioService();
      final settings = AudioFeedbackSettings(initialMusicEnabled: true);
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: settings,
      );
      addTearDown(coordinator.dispose);
      audio.calls.clear();

      settings.setMusicEnabled(false);

      expect(audio.calls, ['stopMusic']);
    });

    test('turning music on, off, then on again starts exactly two loops '
        'total', () {
      final audio = FakeAudioService();
      final settings = AudioFeedbackSettings();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: settings,
      );
      addTearDown(coordinator.dispose);

      settings.setMusicEnabled(true);
      settings.setMusicEnabled(false);
      settings.setMusicEnabled(true);

      expect(audio.calls, ['startMusic', 'stopMusic', 'startMusic']);
    });

    test('backgrounding the app pauses music that is playing', () {
      final audio = FakeAudioService();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(initialMusicEnabled: true),
      );
      addTearDown(coordinator.dispose);
      audio.calls.clear();

      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(audio.calls, ['pauseMusic']);
    });

    test('backgrounding the app does nothing when music was never playing', () {
      final audio = FakeAudioService();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(audio.calls, isEmpty);
    });

    test('resuming the app resumes music that is still enabled', () {
      final audio = FakeAudioService();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(initialMusicEnabled: true),
      );
      addTearDown(coordinator.dispose);
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      audio.calls.clear();

      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(audio.calls, ['resumeMusic']);
    });

    test('resuming the app does not resume music the player turned off '
        'while backgrounded', () {
      final audio = FakeAudioService();
      final settings = AudioFeedbackSettings(initialMusicEnabled: true);
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: settings,
      );
      addTearDown(coordinator.dispose);
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      settings.setMusicEnabled(false);
      audio.calls.clear();

      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(audio.calls, isNot(contains('resumeMusic')));
    });
  });

  group('disposal', () {
    test('dispose releases the underlying audio service', () {
      final audio = FakeAudioService();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(),
      );

      coordinator.dispose();

      expect(audio.disposed, isTrue);
    });

    test('calling dispose twice does not throw', () {
      final coordinator = buildSubject(
        audio: FakeAudioService(),
        haptics: FakeHapticService(),
        settings: AudioFeedbackSettings(),
      );

      coordinator.dispose();

      expect(coordinator.dispose, returnsNormally);
    });

    test('a disposed coordinator no longer reacts to settings changes', () {
      final audio = FakeAudioService();
      final settings = AudioFeedbackSettings();
      final coordinator = buildSubject(
        audio: audio,
        haptics: FakeHapticService(),
        settings: settings,
      );
      coordinator.dispose();
      audio.calls.clear();

      settings.setMusicEnabled(true);

      expect(audio.calls, isEmpty);
    });
  });

  group('resilience to playback failures', () {
    test(
      'a throwing audio service does not propagate out of an event call',
      () {
        final audio = FakeAudioService()
          ..failWith['playWin'] = StateError('boom');
        final coordinator = buildSubject(
          audio: audio,
          haptics: FakeHapticService(),
          settings: AudioFeedbackSettings(),
        );
        addTearDown(coordinator.dispose);

        expect(coordinator.onGameWon, returnsNormally);
      },
    );

    test('a throwing haptic service does not propagate out of an event '
        'call', () {
      final haptics = FakeHapticService()
        ..failWith['warning'] = StateError('boom');
      final coordinator = buildSubject(
        audio: FakeAudioService(),
        haptics: haptics,
        settings: AudioFeedbackSettings(),
      );
      addTearDown(coordinator.dispose);

      expect(coordinator.onInvalidGuess, returnsNormally);
    });
  });
}
