import 'dart:async';

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'core/persistence/shared_preferences_store.dart';
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
  }) : wordRepository = wordRepository ?? AssetWordRepository(),
       statisticsRepository =
           statisticsRepository ??
           LocalStatisticsRepository(store: const SharedPreferencesStore());

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

  @override
  State<CowBullApp> createState() => _CowBullAppState();
}

class _CowBullAppState extends State<CowBullApp> {
  static const GameEngine _gameEngine = GameEngine();

  /// Attempt-limit display data for the `rules` feature, keyed by word
  /// length. Read from [GameConfig] only here — the app-level composition
  /// root — and handed to [RulesScreen] as a presentation-neutral map, so
  /// the `rules` feature never needs to import `GameConfig` itself.
  ///
  /// [maxAttempts] depends only on word length, never difficulty (see
  /// [GameConfig]), so the difficulty passed here to satisfy
  /// [GameConfig.forSelection]'s required parameter is arbitrary.
  static final Map<int, int> _attemptLimitsByWordLength = {
    for (final wordLength in const [4, 5, 6])
      wordLength: GameConfig.forSelection(
        wordLength: wordLength,
        difficulty: GameDifficulty.common,
      ).maxAttempts,
  };

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
    _statisticsController = StatisticsController(
      repository: widget.statisticsRepository,
    );
  }

  @override
  void dispose() {
    if (_ownsSettings) _settings.dispose();
    _statisticsController.dispose();
    super.dispose();
  }

  /// Turns the word length and difficulty [HomeScreen] hands back into a
  /// [GameConfig] — the only place that happens, since [HomeScreen] itself
  /// never imports the `game` feature — then pushes [GameScreen] with a
  /// freshly created [GameController]. A [GameController] is created only
  /// here, at the moment a game actually starts, and is owned and disposed
  /// exactly once by [GameScreen] itself.
  ///
  /// The controller's `onGameCompleted` hook is wired to [_recordCompletedGame]
  /// so every won/lost game is recorded into statistics exactly once, right
  /// at the in-progress-to-completed transition — never on a rebuild, an
  /// abandoned game, or a failed startup. [difficulty] is passed straight
  /// through to the eventual completed-game record: it is already the
  /// feature-neutral [DifficultyOption] statistics needs, so no separate
  /// `GameDifficulty`-to-neutral mapping is needed at completion time.
  void _startGame(
    BuildContext context,
    int wordLength,
    DifficultyOption difficulty,
  ) {
    final config = GameConfig.forSelection(
      wordLength: wordLength,
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
            onGameCompleted: (completionId, session) => _recordCompletedGame(
              id: completionId,
              config: config,
              difficulty: difficulty,
              session: session,
            ),
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
    unawaited(
      _pushOnce(
        context,
        (_) =>
            RulesScreen(attemptLimitsByWordLength: _attemptLimitsByWordLength),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    unawaited(
      _pushOnce(
        context,
        (_) => ListenableBuilder(
          listenable: _settings,
          builder: (context, _) => SettingsScreen(
            themePreference: _settings.themePreference,
            onThemePreferenceChanged: _settings.setThemePreference,
          ),
        ),
      ),
    );
  }

  /// Opens the Statistics screen, kicking off a [StatisticsController.load]
  /// first if the controller isn't already [StatisticsReady] — e.g. on the
  /// very first visit, or a retry after a previous [StatisticsFailure].
  /// When a completed game was already recorded earlier in this app
  /// session, the controller is already [StatisticsReady] with fresh data,
  /// so no reload is needed here.
  void _openStatistics(BuildContext context) {
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
          builder: (context) => HomeScreen(
            onStartGame: (wordLength, difficulty) =>
                _startGame(context, wordLength, difficulty),
            onOpenRules: () => _openRules(context),
            onOpenSettings: () => _openSettings(context),
            onOpenStatistics: () => _openStatistics(context),
          ),
        ),
      ),
    );
  }
}
