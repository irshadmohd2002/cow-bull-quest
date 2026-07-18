import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'audio_feedback_settings.dart';
import 'core/audio/audio_service.dart';
import 'core/feedback/game_feedback.dart';
import 'core/haptics/haptic_service.dart';

/// The delay between the coin-spent and hint-used sound effects for a paid
/// hint — long enough that the two are heard as a distinct, controlled
/// sequence rather than a single overlapping burst, short enough that the
/// pairing still reads as one action.
const Duration _paidHintSfxGap = Duration(milliseconds: 220);

/// Ties [AudioService], [HapticService], and [AudioFeedbackSettings]
/// together into the single app-wide feedback seam every screen and
/// controller reports through — `CowBullApp`'s composition root owns one
/// instance for the app's lifetime and disposes it.
///
/// This is the only place that maps a gameplay/UI event onto specific
/// sound-effect and haptic calls, and the only place that gates every call
/// on the matching [AudioFeedbackSettings] preference — [AudioService] and
/// [HapticService] themselves are unconditional players with no notion of
/// "enabled". Implements [GameFeedback] so `GameController` can report its
/// own outcomes (accepted/rejected guesses, hints, win/loss) directly,
/// without knowing anything about audio, haptics, or this coordinator's
/// other responsibilities.
///
/// **Background-music lifecycle.** Music start/stop is driven entirely by
/// [AudioFeedbackSettings.musicEnabled] (via [_syncMusicWithSettings],
/// invoked once at construction and again on every settings change) —
/// never by a screen's build method — so navigating between screens or
/// rebuilding for an unrelated reason can never restart the loop or start a
/// second, overlapping one; [_musicPlaying] guards every start/stop call so
/// toggling the same value twice in a row (or a settings change that
/// doesn't actually flip the value) is a no-op. Registers itself as a
/// [WidgetsBindingObserver] to pause music the moment the app becomes
/// inactive, paused, hidden, or detached, and resume it only once the app
/// is [AppLifecycleState.resumed] again *and* music is still enabled at
/// that moment — an app resumed after the player turned music off while
/// backgrounded never resumes playback.
class AudioFeedbackCoordinator
    with WidgetsBindingObserver
    implements GameFeedback {
  AudioFeedbackCoordinator({
    required AudioService audioService,
    required HapticService hapticService,
    required AudioFeedbackSettings settings,
  }) {
    _audioService = audioService;
    _hapticService = hapticService;
    _settings = settings;
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_syncMusicWithSettings);
    _syncMusicWithSettings();
  }

  late final AudioService _audioService;
  late final HapticService _hapticService;
  late final AudioFeedbackSettings _settings;

  /// Whether music is currently intended to be playing (started and not yet
  /// stopped) — independent of whether the app is foregrounded right now.
  /// Distinct from [_settings.musicEnabled] only for the instant between a
  /// settings change and [_syncMusicWithSettings] applying it; used by the
  /// lifecycle observer to decide whether a resume should resume playback.
  bool _musicPlaying = false;

  bool _disposed = false;

  void _log(Object error) {
    if (kDebugMode) {
      debugPrint('AudioFeedbackCoordinator: feedback call failed: $error');
    }
  }

  /// Runs [action] without awaiting it here (every public method on this
  /// coordinator is synchronous, matching `GameController`'s own
  /// synchronous outcome methods), while still catching whatever it throws
  /// or its returned [Future] rejects with. [AudioService]/[HapticService]
  /// implementations are documented to never throw, but this is a second,
  /// unconditional line of defense — a playback failure must never surface
  /// as an unhandled async error that could crash the app or a test.
  void _fireAndForget(Future<void> Function() action) {
    unawaited(
      Future.sync(action).catchError((Object error) {
        _log(error);
      }),
    );
  }

  void _syncMusicWithSettings() {
    if (_disposed) return;
    if (_settings.musicEnabled) {
      if (!_musicPlaying) {
        _musicPlaying = true;
        _fireAndForget(_audioService.startMusic);
      }
    } else {
      if (_musicPlaying) {
        _musicPlaying = false;
        _fireAndForget(_audioService.stopMusic);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_musicPlaying && _settings.musicEnabled) {
          _fireAndForget(_audioService.resumeMusic);
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_musicPlaying) {
          _fireAndForget(_audioService.pauseMusic);
        }
    }
  }

  /// Plays the general button-activation sound effect, for an important
  /// navigation/confirmation action (Start Game, Restart, Return Home,
  /// opening a major section). Used sparingly by design — most callers of
  /// this coordinator use a more specific method instead.
  void playButtonTap() {
    if (_disposed) return;
    if (_settings.soundEffectsEnabled) {
      _fireAndForget(_audioService.playButtonTap);
    }
  }

  /// A discrete difficulty was selected on the Home screen.
  void onDifficultySelected() {
    if (_disposed) return;
    if (_settings.hapticsEnabled) {
      _fireAndForget(_hapticService.selectionClick);
    }
  }

  /// The daily-play streak was just started or extended by a qualifying game
  /// completion. Never called for a completion that only re-confirmed a
  /// streak day already counted earlier today — the app-level composition
  /// root only calls this for a genuine `StreakStarted`/`StreakExtended`
  /// result, never `StreakAlreadyCounted`. Haptic-only: no new sound asset is
  /// added for this feedback.
  void onStreakUpdated() {
    if (_disposed) return;
    if (_settings.hapticsEnabled) {
      _fireAndForget(_hapticService.lightImpact);
    }
  }

  /// A Milestone 19 coin reward was just durably persisted for a completed
  /// game — see `CoinWallet.earn`'s `onPersisted` parameter, this method's
  /// only caller (`CowBullApp._awardCoinReward`). Never called for a loss, a
  /// non-rewarding Daily Challenge replay, a rebuild, or a reward whose
  /// persistence write failed.
  ///
  /// Haptic-only, deliberately: this app has exactly one coin-related sound
  /// effect, [AudioService.playCoinSpent], which already carries a "coins
  /// going away" meaning (paired with the hint-used sound for a paid hint —
  /// see [_playPaidHintSfxSequence]); reusing it here for the opposite event
  /// (coins arriving) would send the wrong signal. Rather than add a new
  /// audio asset for one milestone, this follows [onStreakUpdated]'s
  /// existing precedent — a restrained [HapticService.lightImpact], no
  /// sound — and deliberately does *not* reuse [HapticService.success],
  /// since [onGameWon] already fires that haptic (plus [AudioService.playWin])
  /// for every win, including a rewarded one, moments before this call; a
  /// second `success`-strength haptic back to back would read as a jarring
  /// repeat rather than a distinct, restrained follow-up cue.
  void onCoinsEarned() {
    if (_disposed) return;
    if (_settings.hapticsEnabled) {
      _fireAndForget(_hapticService.lightImpact);
    }
  }

  @override
  void onValidGuess() {
    if (_disposed) return;
    if (_settings.hapticsEnabled) {
      _fireAndForget(_hapticService.lightImpact);
    }
  }

  @override
  void onInvalidGuess() {
    if (_disposed) return;
    if (_settings.soundEffectsEnabled) {
      _fireAndForget(_audioService.playInvalidGuess);
    }
    if (_settings.hapticsEnabled) {
      _fireAndForget(_hapticService.warning);
    }
  }

  @override
  void onHintRevealed({required bool paid}) {
    if (_disposed) return;
    if (paid) {
      if (_settings.hapticsEnabled) {
        _fireAndForget(_hapticService.mediumImpact);
      }
      if (_settings.soundEffectsEnabled) {
        _fireAndForget(_playPaidHintSfxSequence);
      }
    } else {
      if (_settings.hapticsEnabled) {
        _fireAndForget(_hapticService.lightImpact);
      }
      if (_settings.soundEffectsEnabled) {
        _fireAndForget(_audioService.playHintUsed);
      }
    }
  }

  /// Plays coin-spent, then hint-used shortly after — a controlled sequence
  /// rather than a simultaneous, overlapping burst — for a paid hint.
  Future<void> _playPaidHintSfxSequence() async {
    await _audioService.playCoinSpent();
    await Future<void>.delayed(_paidHintSfxGap);
    await _audioService.playHintUsed();
  }

  @override
  void onGameWon() {
    if (_disposed) return;
    if (_settings.soundEffectsEnabled) {
      _fireAndForget(_audioService.playWin);
    }
    if (_settings.hapticsEnabled) {
      _fireAndForget(_hapticService.success);
    }
  }

  @override
  void onGameLost() {
    if (_disposed) return;
    if (_settings.soundEffectsEnabled) {
      _fireAndForget(_audioService.playLoss);
    }
    if (_settings.hapticsEnabled) {
      _fireAndForget(_hapticService.mediumImpact);
    }
  }

  /// Releases every resource this coordinator owns: stops observing app
  /// lifecycle and settings changes, and disposes [_audioService]. Call
  /// exactly once, at app shutdown; this instance must not be used again
  /// afterward.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_syncMusicWithSettings);
    _fireAndForget(_audioService.dispose);
  }
}
