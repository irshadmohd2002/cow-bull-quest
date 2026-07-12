import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'features/game/controllers/game_controller.dart';
import 'features/game/data/asset_word_repository.dart';
import 'features/game/data/word_repository.dart';
import 'features/game/models/game_config.dart';
import 'features/game/models/game_difficulty.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/game/services/game_engine.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/rules/presentation/rules_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
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
/// Owns the [WordRepository], [GameEngine], and [AppSettings] for the app's
/// entire lifetime — the repository caches parsed word lists in memory, so
/// reusing one instance across games avoids reparsing assets on every
/// restart; the engine is stateless; and [AppSettings] is the single
/// app-wide theme-preference source every screen shares. No feature imports
/// another feature directly: this is the one place that knows about
/// `home`, `game`, `rules`, and `settings` together, wiring fresh
/// [GameController]s and pushing screens as the home screen requests them.
///
/// [wordRepository] defaults to the real [AssetWordRepository] but can be
/// substituted (e.g. with a fake in widget tests) via constructor
/// injection, so app-level navigation can be exercised without touching
/// real bundled assets. Likewise, [settings] can be injected as a test seam
/// so widget tests can observe or drive theme changes with a controlled
/// instance — see [_CowBullAppState] for exactly who owns disposal in each
/// case.
class CowBullApp extends StatefulWidget {
  CowBullApp({super.key, WordRepository? wordRepository, this.settings})
    : wordRepository = wordRepository ?? AssetWordRepository();

  final WordRepository wordRepository;

  /// An externally-owned settings controller, or `null` to let this widget
  /// create and own its own. When non-null, the caller retains ownership:
  /// this widget uses the exact instance given but never disposes it.
  final AppSettings? settings;

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
  /// verbatim, or one freshly created here. Resolved once in [initState]
  /// and never recreated on rebuild, so a rebuild (e.g. triggered by the
  /// settings change themselves) can never swap out the listened-to
  /// instance mid-lifetime.
  late final AppSettings _settings;

  /// Whether this state created [_settings] itself and therefore must
  /// dispose it. `false` when [_settings] is an externally-injected
  /// instance the caller retains ownership of.
  late final bool _ownsSettings;

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
  }

  @override
  void dispose() {
    if (_ownsSettings) _settings.dispose();
    super.dispose();
  }

  /// Turns the word length and difficulty [HomeScreen] hands back into a
  /// [GameConfig] — the only place that happens, since [HomeScreen] itself
  /// never imports the `game` feature — then pushes [GameScreen] with a
  /// freshly created [GameController]. A [GameController] is created only
  /// here, at the moment a game actually starts, and is owned and disposed
  /// exactly once by [GameScreen] itself.
  void _startGame(
    BuildContext context,
    int wordLength,
    DifficultyOption difficulty,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          config: GameConfig.forSelection(
            wordLength: wordLength,
            difficulty: _toGameDifficulty(difficulty),
          ),
          controller: GameController(
            wordRepository: widget.wordRepository,
            gameEngine: _gameEngine,
          ),
        ),
      ),
    );
  }

  void _openRules(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RulesScreen(attemptLimitsByWordLength: _attemptLimitsByWordLength),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: _settings,
          builder: (context, _) => SettingsScreen(
            themePreference: _settings.themePreference,
            onThemePreferenceChanged: _settings.setThemePreference,
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
        title: 'Bulls & Cows',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _settings.themeMode,
        home: Builder(
          builder: (context) => HomeScreen(
            onStartGame: (wordLength, difficulty) =>
                _startGame(context, wordLength, difficulty),
            onOpenRules: () => _openRules(context),
            onOpenSettings: () => _openSettings(context),
          ),
        ),
      ),
    );
  }
}
