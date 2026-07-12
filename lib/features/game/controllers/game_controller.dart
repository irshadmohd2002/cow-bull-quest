import 'package:flutter/foundation.dart';

import '../data/word_repository.dart';
import '../models/game_config.dart';
import '../models/game_session.dart';
import '../models/game_status.dart';
import '../services/game_engine.dart';
import 'game_controller_state.dart';

/// Coordinates a [WordRepository] and a [GameEngine] into the UI-ready
/// [GameControllerState] a future gameplay screen (and its child widgets)
/// can listen to.
///
/// Extends [ChangeNotifier] — rather than exposing a `Stream` or requiring
/// callers to poll — because shared, observable state is exactly what
/// `ChangeNotifier` is for per this project's state-management guidance
/// (see CLAUDE.md); this controller is the one place in the `game` feature
/// permitted to import `package:flutter/foundation.dart`. It never loads
/// assets or scores guesses itself — both are delegated to the injected
/// [WordRepository] and [GameEngine] so this class stays orchestration-only.
class GameController extends ChangeNotifier {
  GameController({
    required WordRepository wordRepository,
    required GameEngine gameEngine,
  }) : _wordRepository = wordRepository, // ignore: prefer_initializing_formals
       _gameEngine = gameEngine; // ignore: prefer_initializing_formals

  final WordRepository _wordRepository;
  final GameEngine _gameEngine;

  GameControllerState _state = const GameIdle();

  /// The controller's current lifecycle state.
  GameControllerState get state => _state;

  /// The full active/completed session, kept privately so [state] can
  /// expose only the presentation-safe [GameSessionView] while a game is
  /// in progress.
  GameSession? _session;

  GameConfig? _currentConfig;
  int _requestGeneration = 0;
  bool _disposed = false;

  /// Test-only seam: whether an internal session currently exists.
  /// Deliberately exposes a bare `bool` rather than the [GameSession]
  /// itself, so tests can verify session-lifecycle invariants (e.g. that a
  /// failed startup leaves no stale session behind) without giving
  /// presentation code any path to the secret word.
  @visibleForTesting
  bool get debugHasSession => _session != null;

  /// Starts a new game for [config]: asynchronously selects a secret word
  /// through the injected [WordRepository], then begins a session with
  /// [config]'s attempt limit via the injected [GameEngine].
  ///
  /// Immediately clears any previous session and emits [GameLoading], then
  /// either [GameActive] on success or [GameStartupFailure] — preserving
  /// the original thrown error and stack trace — on failure. If startup
  /// fails, no session is created or retained.
  ///
  /// Does nothing if the controller has already been [dispose]d: no
  /// repository or engine work is started, and no state is mutated.
  ///
  /// If another call to [startGame] or [restart] is made before this
  /// call's word selection completes, this call's result is discarded: a
  /// generation counter, bumped on every call (and on [dispose]), lets
  /// each call recognize when it has been superseded or the controller
  /// has been disposed, so neither a slow, stale request nor a late
  /// post-disposal completion can overwrite newer state.
  Future<void> startGame(GameConfig config) async {
    if (_disposed) return;

    final generation = ++_requestGeneration;
    _currentConfig = config;
    _session = null;
    _setState(GameLoading(config));

    try {
      final secretWord = await _wordRepository.selectSecretWord(
        config.wordLength,
      );
      final session = _gameEngine.startGame(
        secretWord: secretWord,
        config: config,
      );
      if (_disposed || generation != _requestGeneration) return;
      _session = session;
      _setState(GameActive(view: GameSessionView.fromSession(session)));
    } catch (error, stackTrace) {
      if (_disposed || generation != _requestGeneration) return;
      _setState(
        GameStartupFailure(
          config: config,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Restarts with the same [GameConfig] as the most recent [startGame]
  /// call, selecting a fresh secret word. Does nothing if no game has been
  /// started yet, or if the controller has already been [dispose]d.
  Future<void> restart() async {
    if (_disposed) return;
    final config = _currentConfig;
    if (config == null) return;
    await startGame(config);
  }

  /// Submits [rawGuess] against the active session through [GameEngine].
  ///
  /// Does nothing if the controller has already been [dispose]d, or if
  /// [state] is not [GameActive] — there is no session to submit against
  /// while idle, loading, completed, or failed, so the call is safely
  /// ignored rather than throwing. On an accepted guess, the session's
  /// [GameSession.status] decides the next state: [GameActive] (with any
  /// stale [GameActive.lastRejection] cleared) while still in-progress, or
  /// [GameCompleted] once won or lost. On a rejected guess,
  /// [GameActive.lastRejection] is set to the typed reason and the session
  /// itself is unchanged.
  void submitGuess(String rawGuess) {
    if (_disposed) return;
    final current = _state;
    if (current is! GameActive) return;
    final session = _session;
    if (session == null) return;

    final submission = _gameEngine.submitGuess(
      session: session,
      rawGuess: rawGuess,
    );
    _session = submission.session;

    switch (submission) {
      case GuessAccepted():
        final updated = submission.session;
        if (updated.status == GameStatus.inProgress) {
          _setState(GameActive(view: GameSessionView.fromSession(updated)));
        } else {
          _setState(GameCompleted(updated));
        }
      case GuessRejected():
        _setState(
          GameActive(
            view: GameSessionView.fromSession(submission.session),
            lastRejection: submission.reason,
          ),
        );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // Invalidates every in-flight startGame call's captured generation, in
    // addition to the explicit _disposed check each of them also performs.
    _requestGeneration++;
    super.dispose();
  }

  void _setState(GameControllerState newState) {
    if (_disposed || identical(_state, newState)) return;
    _state = newState;
    notifyListeners();
  }
}
