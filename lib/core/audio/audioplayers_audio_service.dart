import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_service.dart';

/// Restrained playback volumes (0.0-1.0), kept well below clipping and
/// deliberately unequal: short interface sounds stay quiet, win/loss stay
/// clearly audible without being harsh, and music stays low enough to
/// coexist with every sound effect above it — see [AudioPlayersAudioService]
/// class doc for why music is never explicitly ducked.
class _Volume {
  static const double buttonTap = 0.35;
  static const double sfx = 0.55;
  static const double result = 0.75;
  static const double music = 0.16;
}

const String _sfxAssetPrefix = 'audio/sfx/';
const String _musicAsset = 'audio/music/game_theme.mp3';

/// The real [AudioService], backed by `package:audioplayers`.
///
/// Short sound effects are played through a small round-robin pool of
/// [AudioPlayer] instances (rather than one shared player, or a fresh
/// player per call) so two effects requested close together — e.g. the
/// coin-spent/hint-used pair for a paid hint — can overlap without cutting
/// each other off, while never leaving an unbounded number of short-lived
/// players alive. Background music uses one single, separate, looping
/// player for its entire lifetime.
///
/// **Music/result-effect overlap.** Rather than ducking or pausing music
/// while a win/loss effect plays (which needs extra timing/state to resume
/// correctly), this keeps music at a fixed, low [_Volume.music] — quiet
/// enough that a win/loss effect at [_Volume.result] always reads clearly
/// over it. This is deliberately the simpler of the two acceptable
/// strategies the milestone allows, and avoids a class of bugs where a
/// pause/resume pair around a result effect could race with the player
/// backgrounding at the same moment.
///
/// Every public method swallows its own playback failures (logging in
/// debug mode only) rather than throwing — a missing/corrupt asset, a
/// platform-channel error, or the plugin being unavailable must never break
/// gameplay.
class AudioPlayersAudioService implements AudioService {
  AudioPlayersAudioService({int sfxPoolSize = 3})
    : _sfxPlayers = List.generate(sfxPoolSize, (_) => AudioPlayer());

  final List<AudioPlayer> _sfxPlayers;
  int _nextSfxPlayerIndex = 0;
  final AudioPlayer _musicPlayer = AudioPlayer();

  void _logFailure(String action, Object error) {
    if (kDebugMode) {
      debugPrint('AudioPlayersAudioService: $action failed: $error');
    }
  }

  Future<void> _guard(String action, Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      _logFailure(action, error);
    }
  }

  Future<void> _playSfx(String fileName, double volume) {
    final player = _sfxPlayers[_nextSfxPlayerIndex];
    _nextSfxPlayerIndex = (_nextSfxPlayerIndex + 1) % _sfxPlayers.length;
    return _guard('play $fileName', () async {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      await player.play(AssetSource('$_sfxAssetPrefix$fileName'));
    });
  }

  @override
  Future<void> playButtonTap() => _playSfx('button_tap.mp3', _Volume.buttonTap);

  @override
  Future<void> playInvalidGuess() => _playSfx('invalid_guess.mp3', _Volume.sfx);

  @override
  Future<void> playHintUsed() => _playSfx('hint_used.mp3', _Volume.sfx);

  @override
  Future<void> playCoinSpent() => _playSfx('coin_spent.mp3', _Volume.sfx);

  @override
  Future<void> playWin() => _playSfx('win.mp3', _Volume.result);

  @override
  Future<void> playLoss() => _playSfx('loss.mp3', _Volume.result);

  @override
  Future<void> startMusic() => _guard('start music', () async {
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(_Volume.music);
    await _musicPlayer.play(AssetSource(_musicAsset));
  });

  @override
  Future<void> pauseMusic() => _guard('pause music', _musicPlayer.pause);

  @override
  Future<void> resumeMusic() => _guard('resume music', _musicPlayer.resume);

  @override
  Future<void> stopMusic() => _guard('stop music', _musicPlayer.stop);

  @override
  Future<void> dispose() async {
    for (final player in _sfxPlayers) {
      await _guard('dispose sfx player', player.dispose);
    }
    await _guard('dispose music player', _musicPlayer.dispose);
  }
}
