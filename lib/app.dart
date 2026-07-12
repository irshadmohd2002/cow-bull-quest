import 'package:flutter/material.dart';

import 'features/game/controllers/game_controller.dart';
import 'features/game/data/asset_word_repository.dart';
import 'features/game/data/word_repository.dart';
import 'features/game/models/game_config.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/game/services/game_engine.dart';
import 'features/home/presentation/home_screen.dart';
import 'theme/app_theme.dart';

/// The app's composition root.
///
/// Owns the [WordRepository] and [GameEngine] for the app's entire
/// lifetime — the repository caches parsed word lists in memory, so reusing
/// one instance across games avoids reparsing assets on every restart, and
/// the engine is stateless. Neither feature imports the other directly:
/// this is the one place that knows about both `home` and `game`, wiring a
/// fresh [GameController] and pushing [GameScreen] each time the home screen
/// starts a game.
///
/// [wordRepository] defaults to the real [AssetWordRepository] but can be
/// substituted (e.g. with a fake in widget tests) via constructor
/// injection, so app-level navigation can be exercised without touching
/// real bundled assets.
class CowBullApp extends StatefulWidget {
  CowBullApp({super.key, WordRepository? wordRepository})
    : wordRepository = wordRepository ?? AssetWordRepository();

  final WordRepository wordRepository;

  @override
  State<CowBullApp> createState() => _CowBullAppState();
}

class _CowBullAppState extends State<CowBullApp> {
  static const GameEngine _gameEngine = GameEngine();

  /// Turns the word length [HomeScreen] hands back into a [GameConfig] —
  /// the only place that happens, since [HomeScreen] itself never imports
  /// the `game` feature — then pushes [GameScreen] with a freshly created
  /// [GameController].
  void _startGame(BuildContext context, int wordLength) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          config: GameConfig.forWordLength(wordLength),
          controller: GameController(
            wordRepository: widget.wordRepository,
            gameEngine: _gameEngine,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bulls & Cows',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Builder(
        builder: (context) => HomeScreen(
          onStartGame: (wordLength) => _startGame(context, wordLength),
        ),
      ),
    );
  }
}
