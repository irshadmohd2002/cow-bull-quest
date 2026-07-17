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
import 'core/sharing/result_share_service.dart';
import 'core/sharing/share_plus_result_share_service.dart';
import 'core/time/local_date.dart';
import 'core/time/local_date_provider.dart';
import 'features/daily_challenge/controllers/daily_challenge_controller.dart';
import 'features/daily_challenge/models/daily_challenge_result.dart';
import 'features/daily_challenge/services/daily_challenge_result_share_formatter.dart';
import 'features/daily_challenge/services/daily_challenge_service.dart';
import 'features/game/controllers/game_controller.dart';
import 'features/game/data/asset_word_repository.dart';
import 'features/game/data/fixed_secret_word_repository.dart';
import 'features/game/data/word_repository.dart';
import 'features/game/models/game_config.dart';
import 'features/game/models/game_difficulty.dart';
import 'features/game/models/game_session.dart';
import 'features/game/models/game_status.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/game/services/game_engine.dart';
import 'features/home/models/daily_challenge_card_status.dart';
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
import 'features/streak/controllers/streak_controller.dart';
import 'features/streak/models/streak_update_result.dart';
import 'models/difficulty_selection.dart';
import 'models/streak_feedback.dart';
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
    this.streakController,
    this.dailyChallengeController,
    LocalDateProvider? clock,
    String? privacyPolicyUrl,
    UrlLauncher? urlLauncher,
  }) : wordRepository = wordRepository ?? AssetWordRepository(),
       statisticsRepository =
           statisticsRepository ??
           LocalStatisticsRepository(store: const SharedPreferencesStore()),
       clock = clock ?? const SystemLocalDateProvider(),
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

  /// An externally-owned daily-play-streak controller, or `null` to let this
  /// widget create its own **non-persistent, in-memory only** fallback — the
  /// exact same fallback semantics as [settings] (see its doc above). When
  /// non-null, the caller retains ownership. The real, persistent app entry
  /// point always injects an `AppBootstrap`-loaded controller.
  final StreakController? streakController;

  /// An externally-owned "today's Daily Challenge" controller, or `null` to
  /// let this widget create its own non-persistent, in-memory only fallback
  /// — the same semantics as [streakController]. When non-null, the caller
  /// retains ownership.
  final DailyChallengeController? dailyChallengeController;

  /// The single source of "today" this widget uses wherever it needs the
  /// current calendar date (seeding [streakController]/
  /// [dailyChallengeController]'s own fallbacks, and starting a new Daily
  /// Challenge). Defaults to [SystemLocalDateProvider] (the device's real
  /// local clock); overridable so tests can inject a fixed/fake clock.
  final LocalDateProvider clock;

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

  /// Opens the system share sheet for a completed game's result. Stateless
  /// and holds no resources (unlike [_audioFeedback]), so a single `const`
  /// instance is shared across every [GameScreen] this state creates rather
  /// than owned per-game.
  static const ResultShareService _shareService = SharePlusResultShareService();

  /// Deterministically selects the Daily Challenge secret word. Stateless
  /// and pure, so a single `const` instance is reused for every Daily
  /// Challenge start rather than constructed per call.
  static const DailyChallengeService _dailyChallengeService =
      DailyChallengeService();

  /// Formats an official Daily Challenge result into shareable text.
  /// Stateless and pure, mirroring [_shareService]'s reuse pattern.
  static const DailyChallengeResultShareFormatter
  _dailyChallengeShareFormatter = DailyChallengeResultShareFormatter();

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

  /// The daily-play-streak controller actually in use. Resolved once in
  /// [initState], mirroring [_settings]: shared by [HomeScreen]'s streak
  /// display, the Statistics screen's streak card, and every completed
  /// game's streak recording, so they always agree.
  late final StreakController _streakController;

  /// Whether this state created [_streakController] itself and therefore
  /// must dispose it. `false` when it is an externally-injected instance.
  late final bool _ownsStreakController;

  /// The "today's Daily Challenge" controller actually in use. Resolved once
  /// in [initState], mirroring [_streakController].
  late final DailyChallengeController _dailyChallengeController;

  /// Whether this state created [_dailyChallengeController] itself and
  /// therefore must dispose it. `false` when it is an externally-injected
  /// instance.
  late final bool _ownsDailyChallengeController;

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
    final injectedStreakController = widget.streakController;
    if (injectedStreakController != null) {
      _streakController = injectedStreakController;
      _ownsStreakController = false;
    } else {
      _streakController = StreakController(clock: widget.clock);
      _ownsStreakController = true;
    }
    final injectedDailyChallengeController = widget.dailyChallengeController;
    if (injectedDailyChallengeController != null) {
      _dailyChallengeController = injectedDailyChallengeController;
      _ownsDailyChallengeController = false;
    } else {
      _dailyChallengeController = DailyChallengeController(clock: widget.clock);
      _ownsDailyChallengeController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsSettings) _settings.dispose();
    if (_ownsCoinWallet) _coinWallet.dispose();
    if (_ownsAudioFeedback) _audioFeedback.dispose();
    if (_ownsAudioFeedbackSettings) _audioFeedbackSettings.dispose();
    if (_ownsStreakController) _streakController.dispose();
    if (_ownsDailyChallengeController) _dailyChallengeController.dispose();
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
    final streakFeedback = ValueNotifier<StreakFeedback?>(null);
    final controller = GameController(
      wordRepository: widget.wordRepository,
      gameEngine: _gameEngine,
      coinWallet: _coinWallet,
      feedback: _audioFeedback,
      onGameCompleted: (completionId, session) => _recordCompletedGame(
        id: completionId,
        config: config,
        difficulty: difficulty,
        session: session,
        streakFeedback: streakFeedback,
      ),
    );
    unawaited(
      _pushOnce(
        context,
        // Wrapped in a ListenableBuilder over _streakController (rather than
        // reading its state once, here, before the game even starts) so
        // GameScreen.currentStreak — used only by its *default* Share/Copy
        // text — reflects the streak as of this game's own completion, not
        // whatever it was the moment the player tapped Start Game.
        (_) => ListenableBuilder(
          listenable: _streakController,
          builder: (context, _) => GameScreen(
            config: config,
            controller: controller,
            onButtonTap: _audioFeedback.playButtonTap,
            shareService: _shareService,
            streakFeedback: streakFeedback,
            currentStreak: _streakController.state.currentStreak,
          ),
        ),
      ),
    );
  }

  /// Starts today's Daily Challenge: a 4-letter, Medium-difficulty,
  /// 10-attempt game whose secret word is deterministically selected for
  /// today's date (see [DailyChallengeService]) — the same word for every
  /// player on this word-list version, entirely offline.
  ///
  /// Reuses [GameController]/[GameConfig] exactly like [_startGame]; the
  /// only difference is the secret word is wrapped in a
  /// [FixedSecretWordRepository] rather than left to
  /// [WordRepository.selectSecretWord]'s own random choice, and completion
  /// is recorded through [_recordDailyChallengeCompletion] instead of
  /// [_recordCompletedGame]. [_dailyChallengeController.refresh] is awaited
  /// first so a session spanning a midnight rollover always starts the
  /// challenge for the *current* date, not a stale cached one.
  ///
  /// Replaying after completion is allowed (see `DailyChallengeController`'s
  /// class-level doc): [_recordDailyChallengeCompletion] is safe to call
  /// again for the same date because both the streak and the official
  /// result are idempotent per calendar day — a replay's completion changes
  /// neither.
  Future<void> _startDailyChallenge(BuildContext context) async {
    _audioFeedback.playButtonTap();
    await _dailyChallengeController.refresh();
    if (!context.mounted) return;

    final today = _dailyChallengeController.today;
    final pool = await widget.wordRepository.loadSecretWords(
      DailyChallengeService.wordLength,
      GameDifficulty.common,
    );
    if (!context.mounted) return;
    final secretWord = _dailyChallengeService.secretWordFor(today, pool);

    final config = GameConfig.forSelection(
      wordLength: DailyChallengeService.wordLength,
      difficulty: GameDifficulty.common,
    );
    final dailyWordRepository = FixedSecretWordRepository(
      delegate: widget.wordRepository,
      secretWord: secretWord,
    );
    final streakFeedback = ValueNotifier<StreakFeedback?>(null);
    late final GameController controller;
    controller = GameController(
      wordRepository: dailyWordRepository,
      gameEngine: _gameEngine,
      coinWallet: _coinWallet,
      feedback: _audioFeedback,
      onGameCompleted: (completionId, session) =>
          _recordDailyChallengeCompletion(
            date: today,
            session: session,
            hintsUsed: controller.hintsUsedThisGame,
            streakFeedback: streakFeedback,
          ),
    );
    unawaited(
      _pushOnce(
        context,
        (_) => ListenableBuilder(
          listenable: Listenable.merge([
            _streakController,
            _dailyChallengeController,
          ]),
          builder: (context, _) => GameScreen(
            config: config,
            controller: controller,
            onButtonTap: _audioFeedback.playButtonTap,
            shareService: _shareService,
            streakFeedback: streakFeedback,
            resultTextBuilder: (state, hintsUsed) =>
                _formatDailyChallengeShareText(),
          ),
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
      // Re-derives "today" for the Daily Challenge card every time the
      // player returns to Home from any pushed screen — a cheap no-op
      // whenever the calendar date hasn't changed, but what keeps a
      // long-lived session that happens to cross midnight showing the
      // correct date/status rather than a stale cached one.
      unawaited(_dailyChallengeController.refresh());
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
  ///
  /// Also records today's qualifying streak completion (see
  /// [_recordStreakQualifyingCompletion]) — a normal game and the Daily
  /// Challenge both funnel into the same streak call, so completing either
  /// one first on a given day is what actually earns that day's streak; the
  /// other later that same day is naturally a no-op via
  /// `StreakController`'s own same-day dedupe.
  void _recordCompletedGame({
    required String id,
    required GameConfig config,
    required DifficultyOption difficulty,
    required GameSession session,
    required ValueNotifier<StreakFeedback?> streakFeedback,
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
    _recordStreakQualifyingCompletion(streakFeedback);
  }

  /// Maps a just-finished Daily Challenge [session] onto a neutral
  /// [DailyChallengeResult] and hands it to
  /// [DailyChallengeController.recordIfFirst], which itself only ever keeps
  /// the *first* completion for [date] as official — a later completion
  /// (a practice replay) is a safe no-op here. Also records today's
  /// qualifying streak completion, exactly like [_recordCompletedGame].
  void _recordDailyChallengeCompletion({
    required LocalDate date,
    required GameSession session,
    required int hintsUsed,
    required ValueNotifier<StreakFeedback?> streakFeedback,
  }) {
    final guesses = [
      for (final guess in session.guesses)
        DailyChallengeGuessRecord(
          turnNumber: guess.turnNumber,
          bulls: guess.result.bulls,
          cows: guess.result.cows,
        ),
    ];
    _dailyChallengeController.recordIfFirst(
      DailyChallengeResult(
        date: date,
        won: session.status == GameStatus.won,
        attemptsUsed: session.attemptsUsed,
        maxAttempts: session.maxAttempts,
        hintsUsed: hintsUsed,
        completedAt: DateTime.now(),
        wordListVersion: DailyChallengeService.wordListVersion,
        guesses: guesses,
      ),
    );
    _recordStreakQualifyingCompletion(streakFeedback);
  }

  /// Records today's qualifying streak completion and reports the outcome
  /// through [streakFeedback] (read by [GameScreen]'s completed view) so
  /// every completion path — normal game or Daily Challenge — shows
  /// identical streak feedback. Fires [AudioFeedbackCoordinator.onStreakUpdated]
  /// (a haptic only, no sound) exactly when the streak was genuinely started
  /// or extended — never when today was already counted, matching the
  /// milestone's "do not trigger streak feedback when the same day was
  /// already counted" rule.
  void _recordStreakQualifyingCompletion(
    ValueNotifier<StreakFeedback?> streakFeedback,
  ) {
    final result = _streakController.recordQualifyingCompletion();
    streakFeedback.value = _toStreakFeedback(result);
    if (result is! StreakAlreadyCounted) {
      _audioFeedback.onStreakUpdated();
    }
  }

  /// Maps `features/streak`'s own [StreakUpdateResult] onto the
  /// presentation-safe, shared [StreakFeedback] — the only representation
  /// the `game` feature (which must never import `streak` directly) is ever
  /// handed. Mirrors [_toGameDifficulty]'s role for [DifficultyOption].
  StreakFeedback _toStreakFeedback(StreakUpdateResult result) => StreakFeedback(
    kind: switch (result) {
      StreakStarted() => StreakFeedbackKind.started,
      StreakExtended() => StreakFeedbackKind.extended,
      StreakAlreadyCounted() => StreakFeedbackKind.alreadyCounted,
    },
    currentStreak: result.state.currentStreak,
  );

  /// Builds the Share/Copy text for a Daily Challenge's completed view,
  /// always from [DailyChallengeController.officialResultToday] — the
  /// official, first-completion result — never from a live (possibly
  /// replayed) session, satisfying "a replay must still share the official
  /// result". `officialResultToday` is guaranteed non-null by the time this
  /// can run: [GameScreen] only reaches its completed view, where Share/Copy
  /// become reachable at all, after `onGameCompleted` has already
  /// synchronously called [_recordDailyChallengeCompletion] (which itself
  /// calls `recordIfFirst` synchronously in-memory) for this exact
  /// completion or an earlier one today.
  String _formatDailyChallengeShareText() {
    final official = _dailyChallengeController.officialResultToday;
    if (official == null) {
      // Defensive fallback only; not reachable in normal operation (see the
      // doc above).
      return 'Cow Bull Quest — Daily Challenge';
    }
    return _dailyChallengeShareFormatter.format(
      result: official,
      currentStreak: _streakController.state.currentStreak,
    );
  }

  /// The Daily Challenge card's display state, derived from
  /// [DailyChallengeController.officialResultToday].
  DailyChallengeCardStatus _dailyChallengeCardStatus() {
    final result = _dailyChallengeController.officialResultToday;
    if (result == null) return DailyChallengeCardStatus.notPlayed;
    return result.won
        ? DailyChallengeCardStatus.completedWon
        : DailyChallengeCardStatus.completedNotSolved;
  }

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// A short, human-readable label for [date] (e.g. "18 July 2026"), shown
  /// on the Daily Challenge card. No `intl` dependency: this app only ever
  /// needs this one fixed English format.
  String _formatDate(LocalDate date) =>
      '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

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
          listenable: Listenable.merge([
            _statisticsController,
            _streakController,
          ]),
          builder: (context, _) => StatisticsScreen(
            state: _statisticsController.state,
            onClearStatistics: _statisticsController.clear,
            currentStreak: _streakController.state.currentStreak,
            longestStreak: _streakController.state.longestStreak,
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
            listenable: Listenable.merge([
              _coinWallet,
              _streakController,
              _dailyChallengeController,
            ]),
            builder: (context, _) => HomeScreen(
              onStartGame: (difficulty) => _startGame(context, difficulty),
              onOpenRules: () => _openRules(context),
              onOpenSettings: () => _openSettings(context),
              onOpenStatistics: () => _openStatistics(context),
              onOpenDailyChallenge: () =>
                  unawaited(_startDailyChallenge(context)),
              coinBalance: _coinWallet.balance,
              currentStreak: _streakController.state.currentStreak,
              longestStreak: _streakController.state.longestStreak,
              dailyChallengeStatus: _dailyChallengeCardStatus(),
              dailyChallengeDateLabel: _formatDate(
                _dailyChallengeController.today,
              ),
              onDifficultySelected: (_) =>
                  _audioFeedback.onDifficultySelected(),
            ),
          ),
        ),
      ),
    );
  }
}
