import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher_pkg;

import 'app_settings.dart';
import 'audio_feedback_coordinator.dart';
import 'audio_feedback_settings.dart';
import 'coin_wallet.dart';
import 'core/audio/audioplayers_audio_service.dart';
import 'core/haptics/platform_haptic_service.dart';
import 'core/persistence/shared_preferences_store.dart';
import 'core/privacy_policy.dart' as privacy_policy_config;
import 'features/game/controllers/game_controller.dart';
import 'features/game/data/asset_word_repository.dart';
import 'features/game/data/word_repository.dart';
import 'features/game/models/game_config.dart';
import 'features/game/models/game_difficulty.dart';
import 'features/game/models/game_session.dart';
import 'features/game/models/game_status.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/game/services/game_engine.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/rules/presentation/rules_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/statistics/controllers/statistics_controller.dart';
import 'features/statistics/controllers/statistics_controller_state.dart';
import 'features/statistics/data/local_statistics_repository.dart';
import 'features/statistics/data/statistics_repository.dart';
import 'features/statistics/models/completed_game.dart';
import 'features/statistics/models/game_outcome.dart';
import 'features/statistics/presentation/statistics_screen.dart';
import 'models/difficulty_selection.dart';
import 'theme/app_theme.dart';

/// Maps the `home` feature's neutral [DifficultyOption] onto the `game`
/// feature's own [GameDifficulty]. This composition root is the only place
/// that needs to know both types exist.
GameDifficulty _toGameDifficulty(DifficultyOption option) => switch (option) {
  DifficultyOption.easy => GameDifficulty.easy,
  DifficultyOption.common => GameDifficulty.common,
  DifficultyOption.hard => GameDifficulty.hard,
};

/// Opens [url] externally (the platform browser, or an equivalent external
/// handler), returning whether the launch succeeded.
///
/// Exists as its own function type — rather than calling
/// `package:url_launcher` directly wherever a link is opened — so
/// [CowBullApp.urlLauncher] can substitute a fake in tests without needing a
/// real platform channel, the same test-seam pattern already used for
/// [CowBullApp.wordRepository] and [CowBullApp.statisticsRepository].
typedef UrlLauncher = Future<bool> Function(Uri url);

Future<bool> _launchUrlExternally(Uri url) => url_launcher_pkg.launchUrl(
  url,
  mode: url_launcher_pkg.LaunchMode.externalApplication,
);

/// The app's composition root.
///
/// Owns the [WordRepository], [GameEngine], [AppSettings], and
/// [StatisticsRepository]/[StatisticsController] for the app's entire
/// lifetime — the word repository caches parsed word lists in memory, the
/// engine is stateless, [AppSettings] is the single app-wide theme-
/// preference source every screen shares, and [StatisticsController] is the
/// single app-wide statistics source so recording a completed game while
/// the Statistics screen isn't open still updates it for next time it opens.
/// No feature imports another feature directly: this is the one place that
/// knows about `home`, `game`, `rules`, `settings`, and `statistics`
/// together, wiring fresh [GameController]s and pushing screens as the home
/// screen requests them.
///
/// [wordRepository] and [statisticsRepository] each default to a real
/// implementation but can be substituted (e.g. with a fake in widget tests)
/// via constructor injection. Likewise, [settings] can be injected as a test
/// seam so widget tests can observe or drive theme changes with a
/// controlled instance — see [_CowBullAppState] for exactly who owns
/// disposal in each case.
///
/// **[settings] and persistence.** The real, persistent app entry point
/// (`main.dart`, via `AppBootstrap.load`) always constructs its own
/// [AppSettings] beforehand (already seeded from — and wired to persist
/// back to — real storage) and injects it here as [settings]. When
/// [settings] is omitted, this widget falls back to an in-memory-only
/// `AppSettings()` with **no [PreferencesStore] and therefore no
/// persistence at all** — theme changes made through that fallback are
/// lost the moment this widget is removed from the tree. That fallback
/// exists purely as a convenience for widget tests and other embedding
/// scenarios that don't care about persistence (so they never need to
/// touch platform channels or an injected store just to build a
/// [CowBullApp]); it is never what the shipped app actually runs on. Do not
/// rely on it for persisted behavior — inject a real, `AppBootstrap`-loaded
/// [AppSettings] instead, exactly as `main.dart` does, if persistence is
/// needed. This asymmetry is deliberate: unlike [settings], the
/// [statisticsRepository] fallback below *is* fully persistence-capable
/// (backed by a real [SharedPreferencesStore]) even when not injected,
/// since — unlike a theme flash — there is no equivalent "first frame"
/// concern motivating eager, pre-`runApp` loading for statistics.
class CowBullApp extends StatefulWidget {
  CowBullApp({
    super.key,
    WordRepository? wordRepository,
    this.settings,
    StatisticsRepository? statisticsRepository,
    this.coinWallet,
    this.audioFeedbackSettings,
    this.audioFeedback,
    String? privacyPolicyUrl,
    UrlLauncher? urlLauncher,
  }) : wordRepository = wordRepository ?? AssetWordRepository(),
       statisticsRepository =
           statisticsRepository ??
           LocalStatisticsRepository(store: const SharedPreferencesStore()),
       privacyPolicyUrl =
           privacyPolicyUrl ?? privacy_policy_config.privacyPolicyUrl,
       urlLauncher = urlLauncher ?? _launchUrlExternally;

  final WordRepository wordRepository;

  /// An externally-owned, persistence-capable settings controller, or
  /// `null` to let this widget create its own **non-persistent, in-memory
  /// only** fallback (see the class-level doc above). When non-null, the
  /// caller retains ownership: this widget uses the exact instance given
  /// but never disposes it.
  final AppSettings? settings;

  /// Storage for completed-game statistics. The [StatisticsController] that
  /// wraps it is always created and owned internally (see
  /// [_CowBullAppState._statisticsController]) regardless of where this
  /// repository came from. Unlike [settings]'s fallback, this always
  /// defaults to a real, persistence-capable repository even when not
  /// injected.
  final StatisticsRepository statisticsRepository;

  /// An externally-owned coin wallet, or `null` to let this widget create
  /// its own **non-persistent, in-memory only** fallback — the exact same
  /// fallback semantics as [settings] (see its doc above). When non-null,
  /// the caller retains ownership: this widget uses the exact instance
  /// given but never disposes it. The real, persistent app entry point
  /// always injects an `AppBootstrap`-loaded wallet, exactly as it does for
  /// [settings].
  final CoinWallet? coinWallet;

  /// An externally-owned sound-effects/music/haptics preferences source, or
  /// `null` to let this widget create its own **non-persistent, in-memory
  /// only** fallback — the exact same fallback semantics as [settings] (see
  /// its doc above). When non-null, the caller retains ownership.
  final AudioFeedbackSettings? audioFeedbackSettings;

  /// An externally-owned audio/haptic feedback coordinator, or `null` to
  /// let this widget create its own fallback backed by a real
  /// [AudioPlayersAudioService]/[PlatformHapticService] pair and whichever
  /// [audioFeedbackSettings] this widget resolved to. When non-null, the
  /// caller retains ownership: this widget uses the exact instance given
  /// but never disposes it. The real, persistent app entry point always
  /// injects an `AppBootstrap`-loaded coordinator, exactly as it does for
  /// [settings].
  final AudioFeedbackCoordinator? audioFeedback;

  /// The privacy-policy URL Settings' "Privacy Policy" item opens, or
  /// `null` to use the app's single, centrally-configured
  /// `core/privacy_policy.dart#privacyPolicyUrl`. Overridable only so tests
  /// can exercise the "release-ready URL" path without editing that central
  /// constant; the shipped app always uses the default.
  final String privacyPolicyUrl;

  /// Opens an external URL (the "Privacy Policy" item's action), or `null`
  /// to use the real platform-browser launcher. Overridable so tests can
  /// substitute a fake without a real platform channel; the shipped app
  /// always uses the default.
  final UrlLauncher urlLauncher;

  @override
  State<CowBullApp> createState() => _CowBullAppState();
}

class _CowBullAppState extends State<CowBullApp> {
  static const GameEngine _gameEngine = GameEngine();

  /// The settings instance actually in use — either [CowBullApp.settings]
  /// verbatim, or one freshly created here (non-persistent — see the
  /// class-level doc on [CowBullApp.settings]). Resolved once in [initState]
  /// and never recreated on rebuild, so a rebuild (e.g. triggered by the
  /// settings change themselves) can never swap out the listened-to
  /// instance mid-lifetime.
  late final AppSettings _settings;

  /// Whether this state created [_settings] itself and therefore must
  /// dispose it. `false` when [_settings] is an externally-injected
  /// instance the caller retains ownership of.
  late final bool _ownsSettings;

  /// The coin wallet instance actually in use — either [CowBullApp.coinWallet]
  /// verbatim, or one freshly created here (non-persistent — see the
  /// class-level doc on [CowBullApp.coinWallet]). Resolved once in
  /// [initState], mirroring [_settings]: shared by [HomeScreen]'s balance
  /// display and every [GameController] this state creates when starting a
  /// game, so hint spending and the displayed balance always agree.
  late final CoinWallet _coinWallet;

  /// Whether this state created [_coinWallet] itself and therefore must
  /// dispose it. `false` when [_coinWallet] is an externally-injected
  /// instance the caller retains ownership of.
  late final bool _ownsCoinWallet;

  /// The sound-effects/music/haptics preferences instance actually in use.
  /// Resolved once in [initState], mirroring [_settings]: shared by
  /// [SettingsScreen]'s three switches and [_audioFeedback], so a toggle
  /// there and the behavior this state's [_audioFeedback] applies always
  /// agree.
  late final AudioFeedbackSettings _audioFeedbackSettings;

  /// Whether this state created [_audioFeedbackSettings] itself and
  /// therefore must dispose it. `false` when it is an externally-injected
  /// instance the caller retains ownership of.
  late final bool _ownsAudioFeedbackSettings;

  /// The audio/haptic feedback coordinator actually in use. Resolved once
  /// in [initState]: injected into every [GameController] this state
  /// creates, and called directly for this composition root's own
  /// UI-triggered feedback (button taps, difficulty selection).
  late final AudioFeedbackCoordinator _audioFeedback;

  /// Whether this state created [_audioFeedback] itself and therefore must
  /// dispose it. `false` when [_audioFeedback] is an externally-injected
  /// instance the caller retains ownership of.
  late final bool _ownsAudioFeedback;

  /// The single [StatisticsController] for the app's lifetime, wrapping
  /// [CowBullApp.statisticsRepository]. Always created and disposed by this
  /// state — unlike [_settings], there is no externally-injected seam for
  /// it, since widget tests that need specific statistics states construct
  /// the statistics screen directly instead of going through [CowBullApp].
  late final StatisticsController _statisticsController;

  @override
  void initState() {
    super.initState();
    final injected = widget.settings;
    if (injected != null) {
      _settings = injected;
      _ownsSettings = false;
    } else {
      _settings = AppSettings();
      _ownsSettings = true;
    }
    final injectedWallet = widget.coinWallet;
    if (injectedWallet != null) {
      _coinWallet = injectedWallet;
      _ownsCoinWallet = false;
    } else {
      _coinWallet = CoinWallet();
      _ownsCoinWallet = true;
    }
    final injectedAudioSettings = widget.audioFeedbackSettings;
    if (injectedAudioSettings != null) {
      _audioFeedbackSettings = injectedAudioSettings;
      _ownsAudioFeedbackSettings = false;
    } else {
      _audioFeedbackSettings = AudioFeedbackSettings();
      _ownsAudioFeedbackSettings = true;
    }
    final injectedAudioFeedback = widget.audioFeedback;
    if (injectedAudioFeedback != null) {
      _audioFeedback = injectedAudioFeedback;
      _ownsAudioFeedback = false;
    } else {
      _audioFeedback = AudioFeedbackCoordinator(
        audioService: AudioPlayersAudioService(),
        hapticService: const PlatformHapticService(),
        settings: _audioFeedbackSettings,
      );
      _ownsAudioFeedback = true;
    }
    _statisticsController = StatisticsController(
      repository: widget.statisticsRepository,
    );
  }

  @override
  void dispose() {
    if (_ownsSettings) _settings.dispose();
    if (_ownsCoinWallet) _coinWallet.dispose();
    if (_ownsAudioFeedback) _audioFeedback.dispose();
    if (_ownsAudioFeedbackSettings) _audioFeedbackSettings.dispose();
    _statisticsController.dispose();
    super.dispose();
  }

  /// Turns the difficulty [HomeScreen] hands back into a [GameConfig] — the
  /// only place that happens, since [HomeScreen] itself never imports the
  /// `game` feature — then pushes [GameScreen] with a freshly created
  /// [GameController]. A [GameController] is created only here, at the
  /// moment a game actually starts, and is owned and disposed exactly once
  /// by [GameScreen] itself.
  ///
  /// Every visible game always uses [GameConfig.visibleWordLength] (4
  /// letters, 10 attempts) — [HomeScreen] no longer offers any other word
  /// length (see Milestone 12), so there is no stored or passed-in word
  /// length here that could ever be a stale 5 or 6 from an older install.
  ///
  /// The controller's `onGameCompleted` hook is wired to [_recordCompletedGame]
  /// so every won/lost game is recorded into statistics exactly once, right
  /// at the in-progress-to-completed transition — never on a rebuild, an
  /// abandoned game, or a failed startup. [difficulty] is passed straight
  /// through to the eventual completed-game record: it is already the
  /// feature-neutral [DifficultyOption] statistics needs, so no separate
  /// `GameDifficulty`-to-neutral mapping is needed at completion time.
  void _startGame(BuildContext context, DifficultyOption difficulty) {
    _audioFeedback.playButtonTap();
    final config = GameConfig.forSelection(
      wordLength: GameConfig.visibleWordLength,
      difficulty: _toGameDifficulty(difficulty),
    );
    unawaited(
      _pushOnce(
        context,
        (_) => GameScreen(
          config: config,
          controller: GameController(
            wordRepository: widget.wordRepository,
            gameEngine: _gameEngine,
            coinWallet: _coinWallet,
            feedback: _audioFeedback,
            onGameCompleted: (completionId, session) => _recordCompletedGame(
              id: completionId,
              config: config,
              difficulty: difficulty,
              session: session,
            ),
          ),
          onButtonTap: _audioFeedback.playButtonTap,
        ),
      ),
    );
  }

  /// Whether a route pushed through [_pushOnce] is currently on top of the
  /// navigator. Guards every entry point that pushes a screen (Start Game,
  /// Rules, Settings, Statistics) against a rapid double-tap enqueueing two
  /// [Navigator.push] calls before the first has a chance to render —
  /// otherwise two identical routes could stack, requiring two pops to
  /// actually return home. Reset the instant the pushed route is popped, so
  /// normal sequential navigation (open Rules, return, open Settings) is
  /// never blocked.
  bool _isNavigating = false;

  Future<void> _pushOnce(BuildContext context, WidgetBuilder builder) async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(builder: builder));
    } finally {
      _isNavigating = false;
    }
  }

  /// Maps a just-finished [session] onto a neutral [CompletedGame] and
  /// records it, reusing the exact [id] [GameController] generated (via its
  /// injected `CompletionIdGenerator`) when this game's session started —
  /// this method never generates an ID of its own. A restarted game (a new
  /// [GameController.startGame] call, hence a new session) always gets a
  /// freshly generated `id` from the controller, while
  /// [StatisticsRepository.recordCompletedGame]'s own duplicate-ID guard
  /// protects against this exact call somehow firing twice for the same
  /// session.
  void _recordCompletedGame({
    required String id,
    required GameConfig config,
    required DifficultyOption difficulty,
    required GameSession session,
  }) {
    final outcome = session.status == GameStatus.won
        ? GameOutcome.won
        : GameOutcome.lost;
    unawaited(
      _statisticsController.recordCompletedGame(
        CompletedGame(
          id: id,
          completedAt: DateTime.now(),
          wordLength: config.wordLength,
          difficulty: difficulty,
          outcome: outcome,
          attemptsUsed: session.attemptsUsed,
          maxAttempts: session.maxAttempts,
        ),
      ),
    );
  }

  void _openRules(BuildContext context) {
    _audioFeedback.playButtonTap();
    unawaited(_pushOnce(context, (_) => const RulesScreen()));
  }

  void _openSettings(BuildContext context) {
    _audioFeedback.playButtonTap();
    unawaited(
      _pushOnce(
        context,
        (_) => ListenableBuilder(
          listenable: Listenable.merge([_settings, _audioFeedbackSettings]),
          builder: (context, _) => SettingsScreen(
            themePreference: _settings.themePreference,
            onThemePreferenceChanged: _settings.setThemePreference,
            onOpenPrivacyPolicy:
                privacy_policy_config.isReleaseReadyPrivacyPolicyUrl(
                  widget.privacyPolicyUrl,
                )
                ? () => _openPrivacyPolicy(context)
                : null,
            soundEffectsEnabled: _audioFeedbackSettings.soundEffectsEnabled,
            onSoundEffectsChanged:
                _audioFeedbackSettings.setSoundEffectsEnabled,
            musicEnabled: _audioFeedbackSettings.musicEnabled,
            onMusicChanged: _audioFeedbackSettings.setMusicEnabled,
            hapticsEnabled: _audioFeedbackSettings.hapticsEnabled,
            onHapticsChanged: _audioFeedbackSettings.setHapticsEnabled,
          ),
        ),
      ),
    );
  }

  /// Launches [CowBullApp.privacyPolicyUrl] via [CowBullApp.urlLauncher].
  /// Only ever wired up as the Settings "Privacy Policy" action when
  /// [privacy_policy_config.isReleaseReadyPrivacyPolicyUrl] already
  /// confirmed the URL is well-formed HTTPS, so this never needs to
  /// re-validate it.
  ///
  /// A launch that fails — the platform reports it couldn't be opened, or
  /// [CowBullApp.urlLauncher] throws — shows a brief, friendly snack bar
  /// rather than surfacing the raw failure or exception, and never leaves
  /// the app in a broken state.
  void _openPrivacyPolicy(BuildContext context) {
    unawaited(_launchPrivacyPolicy(context));
  }

  Future<void> _launchPrivacyPolicy(BuildContext context) async {
    var launched = false;
    try {
      launched = await widget.urlLauncher(Uri.parse(widget.privacyPolicyUrl));
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open the privacy policy. Please try again later.",
          ),
        ),
      );
    }
  }

  /// Opens the Statistics screen, kicking off a [StatisticsController.load]
  /// first if the controller isn't already [StatisticsReady] — e.g. on the
  /// very first visit, or a retry after a previous [StatisticsFailure].
  /// When a completed game was already recorded earlier in this app
  /// session, the controller is already [StatisticsReady] with fresh data,
  /// so no reload is needed here.
  void _openStatistics(BuildContext context) {
    _audioFeedback.playButtonTap();
    if (_statisticsController.state is! StatisticsReady) {
      unawaited(_statisticsController.load());
    }
    unawaited(
      _pushOnce(
        context,
        (_) => ListenableBuilder(
          listenable: _statisticsController,
          builder: (context, _) => StatisticsScreen(
            state: _statisticsController.state,
            onClearStatistics: _statisticsController.clear,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => MaterialApp(
        title: 'Cow Bull Quest',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _settings.themeMode,
        home: Builder(
          builder: (context) => ListenableBuilder(
            listenable: _coinWallet,
            builder: (context, _) => HomeScreen(
              onStartGame: (difficulty) => _startGame(context, difficulty),
              onOpenRules: () => _openRules(context),
              onOpenSettings: () => _openSettings(context),
              onOpenStatistics: () => _openStatistics(context),
              coinBalance: _coinWallet.balance,
              onDifficultySelected: (_) =>
                  _audioFeedback.onDifficultySelected(),
            ),
          ),
        ),
      ),
    );
  }
}
