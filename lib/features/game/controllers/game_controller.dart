import 'package:flutter/foundation.dart';

import '../../../coin_wallet.dart';
import '../data/word_repository.dart';
import '../models/game_config.dart';
import '../models/game_session.dart';
import '../models/game_status.dart';
import '../models/hint_state.dart';
import '../services/completion_id_generator.dart';
import '../services/game_engine.dart';
import '../services/hint_policy.dart';
import '../services/hint_service.dart';
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
    CoinWallet? coinWallet,
    HintService hintService = const HintService(),
    HintPolicy hintPolicy = const HintPolicy(),
    CompletionIdGenerator completionIdGenerator =
        const SecureRandomCompletionIdGenerator(),
    void Function(String completionId, GameSession session)? onGameCompleted,
  }) : _wordRepository = wordRepository, // ignore: prefer_initializing_formals
       _gameEngine = gameEngine, // ignore: prefer_initializing_formals
       _coinWallet = coinWallet ?? CoinWallet(),
       _ownsCoinWallet = coinWallet == null,
       _hintService = hintService, // ignore: prefer_initializing_formals
       _hintPolicy = hintPolicy, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _completionIdGenerator = completionIdGenerator,
       // ignore: prefer_initializing_formals
       _onGameCompleted = onGameCompleted;

  final WordRepository _wordRepository;
  final GameEngine _gameEngine;
  final CompletionIdGenerator _completionIdGenerator;

  /// The coin wallet hint purchases spend from. Defaults to a fresh,
  /// non-persistent, 100-coin [CoinWallet] when not injected — the same
  /// fallback pattern `CowBullApp.settings` uses — so existing callers and
  /// tests that don't care about coins/hints are unaffected. The real,
  /// shipped app always injects the single app-wide wallet Home also
  /// displays (see `app.dart`), so hint spending and the displayed balance
  /// stay in sync.
  final CoinWallet _coinWallet;

  /// Whether this controller created [_coinWallet] itself and therefore
  /// must dispose it. `false` when a wallet was injected — the caller
  /// retains ownership of an injected instance, exactly like
  /// `CowBullApp._ownsSettings`.
  final bool _ownsCoinWallet;

  final HintService _hintService;
  final HintPolicy _hintPolicy;

  /// The read-only coin wallet backing this controller's hints. Exposed so
  /// presentation code (the gameplay screen) can display/observe the
  /// current balance and decide whether a paid hint is affordable, without
  /// a second, separately-injected reference to the same instance. Actual
  /// spending only ever happens through [useHint].
  CoinWallet get coinWallet => _coinWallet;

  /// Every hint revealed so far in the current game. Reset to
  /// [HintState.initial] every time [startGame] runs (including via
  /// [restart]) — hint usage never carries over between games, and a
  /// restarted game never refunds coins already spent on hints in the
  /// previous attempt.
  HintState _hintState = HintState.initial;

  /// Called exactly once per game, at the moment its session transitions
  /// from in-progress to won or lost — never on a widget rebuild, never for
  /// a game abandoned mid-session, and never for a failed startup. Receives
  /// the same `completionId` that was generated when this game's
  /// [startGame] call succeeded (see [_activeCompletionId]). Left `null` by
  /// default; the app-level composition root supplies it to record
  /// completed-game statistics without this controller (or the `game`
  /// feature at all) knowing statistics exist.
  final void Function(String completionId, GameSession session)?
  _onGameCompleted;

  GameControllerState _state = const GameIdle();

  /// The controller's current lifecycle state.
  GameControllerState get state => _state;

  /// The full active/completed session, kept privately so [state] can
  /// expose only the presentation-safe [GameSessionView] while a game is
  /// in progress.
  GameSession? _session;

  /// The ID generated for the current session when its [startGame] call
  /// succeeded, retained alongside [_session] for the rest of that game's
  /// lifetime. Deliberately never exposed through [state]/[GameSessionView]
  /// — presentation code has no genuine need for it; only [_onGameCompleted]
  /// receives it, at the moment of completion.
  String? _activeCompletionId;

  GameConfig? _currentConfig;
  int _requestGeneration = 0;
  bool _disposed = false;

  /// The normalized (lowercase) allowed-guess dictionary for the active
  /// session's word length, loaded once alongside the secret word in
  /// [startGame] and reused for every [submitGuess] call in that session —
  /// so guess validation never re-reads the word-list asset mid-game. `null`
  /// whenever no session is active.
  Set<String>? _allowedGuesses;

  /// Test-only seam: whether an internal session currently exists.
  /// Deliberately exposes a bare `bool` rather than the [GameSession]
  /// itself, so tests can verify session-lifecycle invariants (e.g. that a
  /// failed startup leaves no stale session behind) without giving
  /// presentation code any path to the secret word.
  @visibleForTesting
  bool get debugHasSession => _session != null;

  /// Test-only seam: the ID retained for the current session, if any.
  /// Exposed so tests can verify ID lifecycle invariants (generated once
  /// per successful start, cleared on failure, never regenerated by a
  /// stale result) without relying on indirectly observing it through a
  /// completed game.
  @visibleForTesting
  String? get debugActiveCompletionId => _activeCompletionId;

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
    _allowedGuesses = null;
    _activeCompletionId = null;
    _hintState = HintState.initial;
    _setState(GameLoading(config));

    try {
      // Both requests are started before either is awaited, so they run
      // concurrently rather than sequentially.
      final secretWordFuture = _wordRepository.selectSecretWord(
        config.wordLength,
        config.difficulty,
      );
      final allowedWordsFuture = _wordRepository.loadAllowedWords(
        config.wordLength,
      );
      final secretWord = await secretWordFuture;
      final allowedWords = await allowedWordsFuture;
      final session = _gameEngine.startGame(
        secretWord: secretWord,
        config: config,
      );
      if (_disposed || generation != _requestGeneration) return;
      _session = session;
      _allowedGuesses = Set.unmodifiable(allowedWords);
      // Generated exactly once per successful start, only reachable past
      // the generation/disposal guard above, so neither a stale nor a
      // post-disposal completion can assign — or reassign — this.
      _activeCompletionId = _completionIdGenerator.generate();
      _setState(
        GameActive(
          view: GameSessionView.fromSession(session),
          hintState: _hintState,
        ),
      );
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
    final allowedGuesses = _allowedGuesses;
    if (allowedGuesses == null) return;

    final submission = _gameEngine.submitGuess(
      session: session,
      rawGuess: rawGuess,
      allowedGuesses: allowedGuesses,
    );
    _session = submission.session;

    switch (submission) {
      case GuessAccepted():
        final updated = submission.session;
        if (updated.status == GameStatus.inProgress) {
          _setState(
            GameActive(
              view: GameSessionView.fromSession(updated),
              hintState: _hintState,
            ),
          );
        } else {
          _setState(GameCompleted(updated));
          final completionId = _activeCompletionId;
          if (completionId != null) {
            _onGameCompleted?.call(completionId, updated);
          }
        }
      case GuessRejected():
        _setState(
          GameActive(
            view: GameSessionView.fromSession(submission.session),
            lastRejection: submission.reason,
            hintState: _hintState,
          ),
        );
    }
  }

  /// Hint availability and pricing for the current game; `null` whenever no
  /// game is active (idle, loading, completed, or a failed startup) — hints
  /// are only ever available during [GameActive]. See [HintAvailability]
  /// for exactly what each field means.
  HintAvailability? get hintAvailability {
    final session = _session;
    final config = _currentConfig;
    if (_state is! GameActive || session == null || config == null) {
      return null;
    }

    final maxHints = _hintPolicy.maxHints(config.difficulty);
    final hintsUsed = _hintState.hintsUsed;
    if (hintsUsed >= maxHints) {
      return HintAvailability(
        canRequestHint: false,
        hintsUsed: hintsUsed,
        maxHints: maxHints,
        nextHintCost: 0,
      );
    }

    final computation = _hintService.computeHint(
      secretWord: session.secretWord,
      guesses: session.guesses,
      previousHints: _hintState.revealedHints,
    );
    return HintAvailability(
      canRequestHint: computation is HintComputed,
      hintsUsed: hintsUsed,
      maxHints: maxHints,
      nextHintCost: _hintPolicy.costFor(config.difficulty, hintsUsed),
    );
  }

  /// Attempts to reveal the next hint for the current game, spending coins
  /// from [coinWallet] if this hint is paid.
  ///
  /// Independently re-validates every eligibility rule itself — game
  /// active, hint limit not reached, a useful hint still exists, and (for a
  /// paid hint) sufficient coin balance — rather than trusting a caller's
  /// possibly-stale [hintAvailability] read, since UI-observed state can go
  /// stale between a button tap and this call actually running. Coins are
  /// deducted only after a useful hint has actually been computed, and only
  /// if that deduction succeeds; every failure path below returns
  /// [HintNotRevealed] without charging anything or mutating [state].
  ///
  /// This entire method runs synchronously with no `await` — the hint
  /// computation, the wallet check-and-deduct, and the resulting state
  /// update all happen within one call — so two calls made back-to-back can
  /// never both charge for what should be a single hint: the first call's
  /// effects (an incremented hint count, and — for a paid hint — a reduced
  /// wallet balance) are already visible to the second by the time it runs.
  HintOutcome useHint() {
    if (_disposed || _state is! GameActive) {
      return const HintNotRevealed(HintUnavailableReason.gameNotActive);
    }
    final session = _session;
    final config = _currentConfig;
    if (session == null || config == null) {
      return const HintNotRevealed(HintUnavailableReason.gameNotActive);
    }

    final maxHints = _hintPolicy.maxHints(config.difficulty);
    final hintsUsed = _hintState.hintsUsed;
    if (hintsUsed >= maxHints) {
      return const HintNotRevealed(HintUnavailableReason.limitReached);
    }

    final computation = _hintService.computeHint(
      secretWord: session.secretWord,
      guesses: session.guesses,
      previousHints: _hintState.revealedHints,
    );
    if (computation is! HintComputed) {
      return const HintNotRevealed(HintUnavailableReason.noUsefulHintRemains);
    }

    final cost = _hintPolicy.costFor(config.difficulty, hintsUsed);
    if (cost > 0 && !_coinWallet.spend(cost)) {
      return const HintNotRevealed(HintUnavailableReason.insufficientCoins);
    }

    _hintState = _hintState.withHint(computation.hint);
    final current = _state as GameActive;
    _setState(
      GameActive(
        view: current.view,
        lastRejection: current.lastRejection,
        hintState: _hintState,
      ),
    );
    return HintRevealed(hint: computation.hint, coinsSpent: cost);
  }

  @override
  void dispose() {
    _disposed = true;
    // Invalidates every in-flight startGame call's captured generation, in
    // addition to the explicit _disposed check each of them also performs.
    _requestGeneration++;
    if (_ownsCoinWallet) _coinWallet.dispose();
    super.dispose();
  }

  void _setState(GameControllerState newState) {
    if (_disposed || identical(_state, newState)) return;
    _state = newState;
    notifyListeners();
  }
}
