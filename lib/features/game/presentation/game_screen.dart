import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/sharing/share_card_renderer.dart';
import '../../../core/sharing/share_card_service.dart';
import '../../../models/daily_challenge_share_data.dart';
import '../../../models/normal_win_share_data.dart';
import '../../../models/streak_feedback.dart';
import '../../../services/share_caption_formatter.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_status_colors.dart';
import '../../../widgets/coin_balance_badge.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/share_cards/daily_challenge_share_card.dart';
import '../../../widgets/share_cards/normal_win_share_card.dart';
import '../../../widgets/share_cards/share_card_preview_dialog.dart';
import '../controllers/game_controller.dart';
import '../controllers/game_controller_state.dart';
import '../models/game_config.dart';
import '../models/game_difficulty.dart';
import '../models/game_status.dart';
import '../services/coin_reward_calculator.dart';
import '../services/guess_validator.dart';
import 'widgets/game_status_panel.dart';
import 'widgets/guess_history.dart';
import 'widgets/guess_input.dart';
import 'widgets/hint_section.dart';

/// Builds share captions for a completed game's share card. Stateless and
/// pure, so a single module-level instance is reused for every share request
/// rather than constructed per call.
const ShareCaptionFormatter _captionFormatter = ShareCaptionFormatter();

/// Maps a [GuessValidationFailure] to concise, human-facing text.
///
/// Deliberately lives here, in the presentation layer, rather than on the
/// domain enum itself — the domain layer only ever exposes typed reasons.
String _validationMessage(GuessValidationFailure reason, int wordLength) {
  switch (reason) {
    case GuessValidationFailure.blank:
      return 'Enter a guess before submitting.';
    case GuessValidationFailure.incorrectLength:
      return 'Your guess must be exactly $wordLength letters.';
    case GuessValidationFailure.nonAlphabetic:
      return 'Guesses can only contain letters A-Z.';
    case GuessValidationFailure.notInDictionary:
      return "That's not a word we recognize. Try another guess.";
    case GuessValidationFailure.gameAlreadyWon:
      return 'You already won this game.';
    case GuessValidationFailure.gameAlreadyLost:
      return 'This game has already ended.';
  }
}

/// Maps a [GameDifficulty] to concise, human-facing text.
///
/// Deliberately lives here, in the presentation layer, rather than on the
/// domain enum itself — the domain layer only ever exposes typed values.
String _difficultyLabel(GameDifficulty difficulty) => switch (difficulty) {
  GameDifficulty.easy => 'Easy',
  GameDifficulty.common => 'Medium',
  GameDifficulty.hard => 'Hard',
};

/// The gameplay screen: shows the active session, accepts guesses, and
/// shows the win/loss outcome.
///
/// Consumes [GameController] only — it never talks to a `WordRepository` or
/// `GameEngine` directly. [controller] is created by the caller (the
/// app-level composition root) for this one game flow and is owned by this
/// screen: it is started in [initState] and disposed in [dispose], so no
/// disposed controller can ever be reused and no controller outlives its
/// game flow.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.controller,
    required this.config,
    this.onButtonTap,
    this.shareCardRenderer = const OffscreenShareCardRenderer(),
    this.shareCardService = const SharePlusShareCardService(),
    this.streakFeedback,
    this.coinsEarnedFeedback,
    this.dailyChallengeReplayFeedback,
    this.dailyChallengeShareData,
  });

  /// The controller for this game flow. Owned by this screen.
  final GameController controller;

  /// The configuration this screen was started (and is restarted) with.
  final GameConfig config;

  /// Called for this screen's own important navigation actions (Restart,
  /// Home, Share Win/Challenge) so the caller can play a
  /// button-activation sound, or `null` to play none. Deliberately generic —
  /// this screen never imports anything audio/haptic-related itself; the
  /// app-level composition root supplies the real behavior (see `app.dart`).
  final VoidCallback? onButtonTap;

  /// Renders a share card to PNG bytes. Defaults to the real, offscreen
  /// `RepaintBoundary`-backed implementation; tests substitute a fake so no
  /// real widget-tree capture is ever driven.
  final ShareCardRenderer shareCardRenderer;

  /// Hands a rendered share card to the system share sheet. Defaults to the
  /// real, `share_plus`-backed implementation; tests substitute a fake so no
  /// platform channel is ever touched.
  final ShareCardService shareCardService;

  /// Set exactly once, synchronously, by the app-level composition root at
  /// the moment this game's completion is recorded (see
  /// `GameController.onGameCompleted`) — `null` until then. When the
  /// completed view renders, a non-null, non-"already counted" value shows a
  /// restrained, one-time entrance animation alongside streak text (see
  /// [StreakFeedback]); the animation is keyed off the specific
  /// [GameCompleted] instance, so it never replays on an unrelated rebuild.
  /// `null` throughout (the default) simply renders no streak feedback at
  /// all — existing callers/tests that don't care about streaks are
  /// unaffected.
  final ValueNotifier<StreakFeedback?>? streakFeedback;

  /// Set exactly once, synchronously, by the app-level composition root at
  /// the same moment as [streakFeedback] (see its doc) — the itemized
  /// Milestone 19 coin reward for this completion, or `null` for none (a
  /// loss, an abandoned/restarted game — neither of which ever reaches this
  /// far — or a Daily Challenge replay). When the completed view renders, a
  /// non-null value shows a compact "Coins earned" breakdown card alongside
  /// the outcome. `null` throughout (the default) simply shows no
  /// coin-reward card at all — existing callers/tests that don't care about
  /// coin rewards are unaffected.
  final ValueNotifier<CoinRewardBreakdown?>? coinsEarnedFeedback;

  /// Set exactly once, synchronously, by the app-level composition root at
  /// the same moment as [streakFeedback] — but only for a Daily Challenge
  /// session — to whether this specific completion was a practice replay
  /// (`true`) or today's official attempt (`false`). `null` throughout for
  /// every normal (non-Daily-Challenge) game, which never sets this at all.
  /// When the completed view renders `true`, it shows an explicit "replay —
  /// no additional coins" notice, so a Daily Challenge replay is never
  /// ambiguous with an official loss (both otherwise show no coin-reward
  /// card, but only a replay should say so). Also doubles as this screen's
  /// "is this a Daily Challenge session at all" signal (non-`null` exactly
  /// for a Daily Challenge session): the completed view shows "Share Win"
  /// for a normal game, or "Share Challenge" for a Daily Challenge session —
  /// never both, and never falls back from one to the other.
  final ValueNotifier<bool?>? dailyChallengeReplayFeedback;

  /// The official Daily Challenge result's share-card data, or `null`.
  ///
  /// Set by the app-level composition root only when
  /// [dailyChallengeReplayFeedback] is non-null (a Daily Challenge session)
  /// *and* the official (first-of-the-day) result is a win — a `null` here
  /// on an otherwise-Daily-Challenge screen means the official result is a
  /// loss (or not yet recorded), so Share Challenge is never shown, even if
  /// this specific completed view is itself a replay win. Always built from
  /// the saved official result, never a live/replayed session, so a replay
  /// after an official win still shares the exact same card (see the
  /// milestone's own "a replay must still use the saved official winning
  /// result" rule).
  final DailyChallengeShareData? dailyChallengeShareData;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TextEditingController _guessTextController = TextEditingController();
  final FocusNode _guessFocusNode = FocusNode();
  bool _submitting = false;

  /// Bumped on every rejected submission, including ones whose message is
  /// identical to the previous rejection. Used only to key the validation
  /// banner's animation so a repeated identical rejection still visibly
  /// flashes rather than silently no-opping.
  int _rejectionSequence = 0;

  /// Set the instant a hint request begins (before any `await`, i.e. before
  /// a paid hint's confirmation dialog is even shown) and cleared once it
  /// settles. Guards against a rapid double-tap on the Hint button
  /// triggering two overlapping requests — and, by extension, two
  /// deductions — for what the player intended as a single hint, the same
  /// pattern [_submitting] already uses for guess submission.
  bool _hintBusy = false;

  /// Set the instant a Share Win/Challenge tap begins opening the share-card
  /// preview sheet, and cleared once that sheet closes. Guards against a
  /// rapid double-tap opening two overlapping preview sheets, the same
  /// pattern [_hintBusy] uses for hints.
  bool _openingShare = false;

  /// Set the instant a leave/restart confirmation dialog begins and cleared
  /// once it settles. Guards against a rapid double-tap on the Restart
  /// action, or a rapid double back-gesture, opening two overlapping
  /// confirmation dialogs — the same pattern [_hintBusy] uses for hints. A
  /// single flag safely covers both dialogs since a player can only be
  /// looking at one of them at a time.
  bool _confirmationBusy = false;

  /// Set the instant Home is tapped from the completed view.
  /// Guards against a rapid double-tap firing two overlapping
  /// [Navigator.pop] calls — which, unlike a double-tap on Restart (already
  /// safely debounced by [GameController]'s own generation counter), could
  /// otherwise pop past this screen and into Home itself.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.startGame(widget.config));
  }

  @override
  void dispose() {
    _guessTextController.dispose();
    _guessFocusNode.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  void _handleReturnHome() {
    if (_leaving) return;
    _leaving = true;
    widget.onButtonTap?.call();
    Navigator.of(context).pop();
  }

  void _handleRetry() => unawaited(widget.controller.startGame(widget.config));

  void _handleRestart() {
    widget.onButtonTap?.call();
    _guessTextController.clear();
    unawaited(widget.controller.restart());
  }

  /// Whether at least one guess has been accepted in the current game — the
  /// point past which restarting or leaving would actually lose progress.
  /// `false` whenever no game is active at all (idle, loading, completed —
  /// completion has its own "no confirmation needed" rule handled
  /// separately — or a failed startup).
  bool get _hasAcceptedProgress {
    final state = widget.controller.state;
    return state is GameActive && state.view.attemptsUsed > 0;
  }

  /// Handles a tap on the AppBar's Restart action during active gameplay.
  ///
  /// Restarts immediately, with no dialog, if no guess has been accepted
  /// yet (nothing to lose) — otherwise shows "Restart game?" first and only
  /// restarts if confirmed. [_confirmationBusy] is set synchronously, before
  /// the `await showConfirmDialog`, so a rapid double-tap cannot stack two
  /// overlapping confirmation dialogs.
  Future<void> _handleRestartRequest() async {
    if (_confirmationBusy || widget.controller.state is! GameActive) return;
    if (!_hasAcceptedProgress) {
      _handleRestart();
      return;
    }
    _confirmationBusy = true;
    try {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Restart game?',
        body: 'Your current guesses will be cleared.',
        confirmLabel: 'Restart',
      );
      if (confirmed) _handleRestart();
    } finally {
      if (mounted) _confirmationBusy = false;
    }
  }

  /// Handles an attempt to leave this screen — the system back gesture, or
  /// the AppBar's implied back button — while [_hasAcceptedProgress] is
  /// `true` (see [PopScope.canPop] in [build], which is what routes both of
  /// those here instead of popping immediately). Shows "Leave this game?"
  /// and only actually leaves if confirmed; [_confirmationBusy] guards
  /// against a rapid double back-gesture stacking two dialogs, exactly like
  /// [_handleRestartRequest].
  Future<void> _handleLeaveAttempt() async {
    if (_confirmationBusy) return;
    _confirmationBusy = true;
    try {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Leave this game?',
        body: 'Your current guesses will be lost.',
        confirmLabel: 'Leave',
        cancelLabel: 'Keep playing',
      );
      if (confirmed && mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) _confirmationBusy = false;
    }
  }

  void _handleSubmit(String rawText) {
    if (_submitting) return;
    final text = rawText.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    widget.controller.submitGuess(text);

    final state = widget.controller.state;
    if (state is GameActive) {
      if (state.lastRejection == null) {
        _guessTextController.clear();
      } else {
        _rejectionSequence++;
        _guessTextController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _guessTextController.text.length,
        );
      }
      _guessFocusNode.requestFocus();
    }
    setState(() => _submitting = false);
  }

  /// Handles a tap on the Hint button for the current [availability].
  ///
  /// A free hint (Hard's first) is used immediately, with no confirmation.
  /// A paid hint shows a confirmation dialog stating the cost and current
  /// balance first; [GameController.useHint] is only ever called if the
  /// player confirms, and never if they cancel. `_hintBusy` is set
  /// synchronously, before the `await showDialog` below, so a rapid
  /// double-tap on the Hint button itself cannot open two overlapping
  /// requests (see [_hintBusy]'s doc comment).
  Future<void> _handleHintUse(HintAvailability availability) async {
    if (_hintBusy || !availability.canRequestHint) return;
    setState(() => _hintBusy = true);
    try {
      if (availability.nextHintCost > 0) {
        final balance = widget.controller.coinWallet.balance;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Use a hint?'),
            content: Text(
              'This reveals one correct letter and its exact position in '
              'the secret word.\n\n'
              'Cost: ${availability.nextHintCost} coins\n'
              'Your balance: $balance coins',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('Use ${availability.nextHintCost} Coins'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      widget.controller.useHint();
    } finally {
      if (mounted) setState(() => _hintBusy = false);
    }
  }

  /// Opens the share-card preview sheet for [card], which renders once and
  /// shares [fileName]/[caption] if the player confirms.
  ///
  /// `_openingShare` is set synchronously, before the `await`, so a rapid
  /// double-tap on Share Win/Challenge cannot open two overlapping preview
  /// sheets (see [_openingShare]'s doc comment). Never mutates
  /// [GameScreen.controller] or any completed-game/statistics/coin/streak
  /// state — a card preview, its render, and its share are purely additive,
  /// read-only operations.
  Future<void> _openSharePreview({
    required Widget card,
    required String fileName,
    required String caption,
  }) async {
    if (_openingShare) return;
    setState(() => _openingShare = true);
    try {
      await showShareCardPreview(
        context: context,
        card: card,
        fileName: fileName,
        caption: caption,
        renderer: widget.shareCardRenderer,
        service: widget.shareCardService,
        onButtonTap: widget.onButtonTap,
      );
    } finally {
      if (mounted) setState(() => _openingShare = false);
    }
  }

  /// The Share Win/Challenge tap handler for [state]'s completed view, or
  /// `null` to show no share action at all.
  ///
  /// A Daily Challenge session ([GameScreen.dailyChallengeReplayFeedback]
  /// non-`null`) always shares [GameScreen.dailyChallengeShareData] — the
  /// saved *official* result — when it is non-`null` (an official win),
  /// regardless of whether this specific completed view is itself a replay
  /// win or loss; `null` there (an official loss, or not yet recorded) means
  /// no share action, ever, for that Daily Challenge session. A normal game
  /// only offers a share action for its own live win — never for a loss.
  VoidCallback? _shareHandlerFor(GameCompleted state, int hintsUsed) {
    if (widget.dailyChallengeReplayFeedback != null) {
      final data = widget.dailyChallengeShareData;
      if (data == null) return null;
      return () => unawaited(
        _openSharePreview(
          card: DailyChallengeShareCard(data: data),
          fileName: 'cow-bull-quest-daily-challenge.png',
          caption: _captionFormatter.dailyChallengeWin(data),
        ),
      );
    }
    if (state.session.status != GameStatus.won) return null;
    final data = NormalWinShareData(
      difficultyLabel: _difficultyLabel(widget.config.difficulty),
      attemptsUsed: state.session.attemptsUsed,
      maxAttempts: state.session.maxAttempts,
      hintsUsed: hintsUsed,
      coinsEarned: widget.coinsEarnedFeedback?.value?.totalCoinsEarned ?? 0,
    );
    return () => unawaited(
      _openSharePreview(
        card: NormalWinShareCard(data: data),
        fileName: 'cow-bull-quest-win.png',
        caption: _captionFormatter.normalWin(data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => PopScope(
        // Only intercepts the system back gesture / the AppBar's implied
        // back button while there is genuine progress to lose — before any
        // guess is accepted, or once the game is complete, leaving is never
        // gated behind a confirmation (see the milestone's own "no
        // confirmation before the first accepted guess" / "no confirmation
        // after completion" rules).
        canPop: !_hasAcceptedProgress,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          unawaited(_handleLeaveAttempt());
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Cow Bull Quest'),
            actions: [
              if (widget.controller.state is GameActive)
                Semantics(
                  button: true,
                  label: 'Restart game',
                  child: ExcludeSemantics(
                    child: IconButton(
                      icon: const Icon(Icons.replay),
                      tooltip: 'Restart game',
                      onPressed: () => unawaited(_handleRestartRequest()),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Center(
                  child: CoinBalanceBadge(
                    balance: widget.controller.coinWallet.balance,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _buildBody(widget.controller.state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(GameControllerState state) {
    return switch (state) {
      GameIdle() || GameLoading() => const _LoadingView(),
      GameActive() => _ActiveGameView(
        state: state,
        guessTextController: _guessTextController,
        guessFocusNode: _guessFocusNode,
        wordLength: widget.config.wordLength,
        difficultyLabel: _difficultyLabel(widget.config.difficulty),
        submitEnabled: !_submitting,
        rejectionSequence: _rejectionSequence,
        onSubmit: _handleSubmit,
        hintAvailability: widget.controller.hintAvailability!,
        coinBalance: widget.controller.coinWallet.balance,
        hintBusy: _hintBusy,
        onUseHint: () =>
            unawaited(_handleHintUse(widget.controller.hintAvailability!)),
      ),
      GameCompleted() => _CompletedGameView(
        state: state,
        hintsUsed: widget.controller.hintsUsedThisGame,
        sharingBusy: _openingShare,
        streakFeedback: widget.streakFeedback?.value,
        coinsEarned: widget.coinsEarnedFeedback?.value,
        isDailyChallengeReplay: widget.dailyChallengeReplayFeedback?.value,
        isDailyChallenge: widget.dailyChallengeReplayFeedback != null,
        difficulty: widget.config.difficulty,
        onRestart: _handleRestart,
        onReturnHome: _handleReturnHome,
        onShare: _shareHandlerFor(state, widget.controller.hintsUsedThisGame),
      ),
      GameStartupFailure() => _StartupFailureView(
        onRetry: _handleRetry,
        onReturnHome: _handleReturnHome,
      ),
    };
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Loading game. Selecting a secret word.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Selecting a secret word...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveGameView extends StatelessWidget {
  const _ActiveGameView({
    required this.state,
    required this.guessTextController,
    required this.guessFocusNode,
    required this.wordLength,
    required this.difficultyLabel,
    required this.submitEnabled,
    required this.rejectionSequence,
    required this.onSubmit,
    required this.hintAvailability,
    required this.coinBalance,
    required this.hintBusy,
    required this.onUseHint,
  });

  final GameActive state;
  final TextEditingController guessTextController;
  final FocusNode guessFocusNode;
  final int wordLength;
  final String difficultyLabel;
  final bool submitEnabled;
  final int rejectionSequence;
  final ValueChanged<String> onSubmit;
  final HintAvailability hintAvailability;
  final int coinBalance;
  final bool hintBusy;
  final VoidCallback onUseHint;

  @override
  Widget build(BuildContext context) {
    final rejection = state.lastRejection;
    final message = rejection == null
        ? null
        : _validationMessage(rejection, wordLength);
    final hintEnabled =
        hintAvailability.canRequestHint &&
        !hintBusy &&
        (hintAvailability.nextHintCost == 0 ||
            coinBalance >= hintAvailability.nextHintCost);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A CustomScrollView with a SliverFillRemaining(hasScrollBody: true)
        // last sliver behaves exactly like Expanded(child: GuessHistory(…))
        // whenever the fixed content above it (status panel, hint section,
        // validation banner) fits within the available height — but unlike
        // a plain Expanded inside this Column, it degrades to a scrollable
        // region instead of a hard RenderFlex overflow if that fixed
        // content alone ever exceeds the available height (e.g. at extreme
        // text-scale factors on a short viewport). GuessInput below stays
        // outside this scroll region so it, and the keyboard it opens,
        // remain fixed at the bottom regardless.
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: GameStatusPanel(
                  view: state.view,
                  difficultyLabel: difficultyLabel,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
              SliverToBoxAdapter(
                child: HintSection(
                  availability: hintAvailability,
                  revealedHints: state.hintState.revealedHints,
                  coinBalance: coinBalance,
                  enabled: hintEnabled,
                  onUseHint: onUseHint,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
              SliverToBoxAdapter(
                child: _ValidationBanner(
                  message: message,
                  sequence: rejectionSequence,
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: GuessHistory(guesses: state.view.guesses),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GuessInput(
          controller: guessTextController,
          focusNode: guessFocusNode,
          wordLength: wordLength,
          enabled: submitEnabled,
          hasError: rejection != null,
          onSubmit: onSubmit,
          rejectionSignal: rejectionSequence,
        ),
      ],
    );
  }
}

/// Shows the most recent validation failure, if any, as a prominent banner
/// above the guess history.
///
/// The single accessible source for this message — its [Semantics] node is
/// the only place the text is announced (the guess field itself carries no
/// duplicate error text). [sequence] changes on every rejection, including
/// consecutive identical ones, which changes this banner's [ValueKey] and
/// so re-triggers the [AnimatedSwitcher] transition even when [message] is
/// unchanged — otherwise a second, identical rejection would produce no
/// visible change at all.
class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.message, required this.sequence});

  final String? message;
  final int sequence;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = message;

    return AnimatedSwitcher(
      duration: AppMotion.durationFor(context, AppMotion.standard),
      switchInCurve: AppMotion.curve,
      child: text == null
          ? const SizedBox.shrink(key: ValueKey('no-validation-error'))
          : Padding(
              key: ValueKey('validation-error-$sequence'),
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Semantics(
                liveRegion: true,
                container: true,
                label: text,
                child: ExcludeSemantics(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _CompletedGameView extends StatelessWidget {
  const _CompletedGameView({
    required this.state,
    required this.hintsUsed,
    required this.sharingBusy,
    this.streakFeedback,
    this.coinsEarned,
    this.isDailyChallengeReplay,
    required this.isDailyChallenge,
    required this.difficulty,
    required this.onRestart,
    required this.onReturnHome,
    required this.onShare,
  });

  final GameCompleted state;

  /// The number of hints used in the game that just ended.
  final int hintsUsed;

  /// Whether the share-card preview sheet is currently being opened —
  /// disables Share Win/Challenge so a rapid double-tap cannot open two
  /// overlapping preview sheets.
  final bool sharingBusy;

  /// What happened to the streak as a result of this completion, or `null`
  /// to show no streak feedback at all. See [GameScreen.streakFeedback].
  final StreakFeedback? streakFeedback;

  /// The itemized coin reward earned by this completion, or `null` to show
  /// no coin-reward card at all. See [GameScreen.coinsEarnedFeedback].
  final CoinRewardBreakdown? coinsEarned;

  /// Whether this completion was a Daily Challenge practice replay, `null`
  /// for every normal game. See [GameScreen.dailyChallengeReplayFeedback].
  final bool? isDailyChallengeReplay;

  /// Whether this completed view belongs to a Daily Challenge session at
  /// all — distinct from [isDailyChallengeReplay], which is only about
  /// *this specific* completion. Picks the share button's label: "Share
  /// Challenge" here, "Share Win" otherwise.
  final bool isDailyChallenge;

  /// The difficulty this game was played at, labeling
  /// [coinsEarned]'s base-win-reward line (e.g. "Medium win").
  final GameDifficulty difficulty;
  final VoidCallback onRestart;
  final VoidCallback onReturnHome;

  /// Opens the share-card preview sheet, or `null` to show no share action
  /// at all — see [GameScreen._shareHandlerFor]'s own doc for exactly when
  /// each case applies.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    final won = session.status == GameStatus.won;
    final outcomeText = won ? 'You won!' : 'Not solved';
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final outcomeColor = won
        ? (statusColors?.success ?? colorScheme.primary)
        : colorScheme.error;
    final outcomeIcon = won ? Icons.emoji_events : Icons.flag;

    // Wrapped in a scrollable, height-flexible container — rather than a
    // plain Column relying on Expanded(GuessHistory) alone to absorb any
    // excess — so this whole screen degrades to scrolling instead of a hard
    // RenderFlex overflow whenever its fixed content (the outcome card, plus
    // the action rows below it, including the Share Win/Challenge action)
    // exceeds the available height on its own (narrow viewports, large
    // text-scale factors). GuessHistory is passed shrinkWrap: true so it
    // sizes to its content within this single outer scrollable, rather than
    // nesting a second, independently-scrolling one.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label:
                    '$outcomeText. The secret word was ${session.secretWord}. '
                    'Attempts used: ${session.attemptsUsed} of '
                    '${session.maxAttempts}. Hints used: $hintsUsed.',
                child: ExcludeSemantics(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: AppMotion.durationFor(
                      context,
                      AppMotion.entrance,
                    ),
                    curve: AppMotion.curve,
                    builder: (context, entrance, child) => Opacity(
                      opacity: entrance,
                      child: Transform.translate(
                        offset: Offset(0, (1 - entrance) * 12),
                        child: child,
                      ),
                    ),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.6, end: 1),
                              duration: AppMotion.durationFor(
                                context,
                                AppMotion.standard,
                              ),
                              curve: Curves.easeOutBack,
                              builder: (context, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                              child: Icon(
                                outcomeIcon,
                                size: 40,
                                color: outcomeColor,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              outcomeText,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Secret word: ${session.secretWord.toUpperCase()}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Attempts used: ${session.attemptsUsed} / '
                              '${session.maxAttempts}',
                            ),
                            Text('Hints used: $hintsUsed'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (coinsEarned != null) ...[
                const SizedBox(height: AppSpacing.md),
                _CoinRewardBreakdownCard(
                  breakdown: coinsEarned!,
                  difficulty: difficulty,
                ),
              ],
              if (isDailyChallengeReplay ?? false) ...[
                const SizedBox(height: AppSpacing.md),
                const _DailyChallengeReplayNotice(),
              ],
              if (streakFeedback != null) ...[
                const SizedBox(height: AppSpacing.md),
                _StreakFeedbackBanner(
                  feedback: streakFeedback!,
                  animationKey: state,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              GuessHistory(guesses: session.guesses, shrinkWrap: true),
              const SizedBox(height: AppSpacing.lg),
              _ResultActions(
                isDailyChallenge: isDailyChallenge,
                sharingBusy: sharingBusy,
                onRestart: onRestart,
                onReturnHome: onReturnHome,
                onShare: onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The completed-view action buttons: a single visually-dominant primary
/// action ("Play Again"/"Replay") followed by secondary actions (Share
/// Win/Challenge, Home). The secondary actions share a row when there's
/// room; otherwise they stack, so neither label ever wraps or overflows at
/// a narrow width or a large text-scale factor.
class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.isDailyChallenge,
    required this.sharingBusy,
    required this.onRestart,
    required this.onReturnHome,
    required this.onShare,
  });

  final bool isDailyChallenge;
  final bool sharingBusy;
  final VoidCallback onRestart;
  final VoidCallback onReturnHome;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = isDailyChallenge ? 'Replay' : 'Play Again';
    final primarySemanticsLabel = isDailyChallenge ? 'Replay' : 'Play again';
    final primaryButton = Semantics(
      button: true,
      label: primarySemanticsLabel,
      child: ExcludeSemantics(
        child: FilledButton.icon(
          onPressed: onRestart,
          icon: const Icon(Icons.replay),
          label: Text(
            primaryLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ),
    );

    final homeButton = Semantics(
      button: true,
      label: 'Home',
      child: ExcludeSemantics(
        child: OutlinedButton.icon(
          onPressed: onReturnHome,
          icon: const Icon(Icons.home_rounded),
          label: const Text(
            'Home',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ),
    );

    final shareHandler = onShare;
    final shareButton = shareHandler == null
        ? null
        : Semantics(
            button: true,
            label: isDailyChallenge ? 'Share challenge' : 'Share win',
            child: ExcludeSemantics(
              child: OutlinedButton.icon(
                onPressed: sharingBusy ? null : shareHandler,
                icon: sharingBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image),
                label: Text(
                  isDailyChallenge ? 'Share Challenge' : 'Share Win',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: double.infinity, child: primaryButton),
        const SizedBox(height: AppSpacing.md),
        if (shareButton == null)
          SizedBox(width: double.infinity, child: homeButton)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // Combines the available width with the active text-scale
              // factor — rather than a bare width breakpoint — so a
              // moderately-narrow phone at default text size still gets a
              // single row, while a wide viewport at a large accessibility
              // text scale (where each label needs much more horizontal
              // room) still stacks instead of compressing or wrapping.
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final stack = constraints.maxWidth < 340 || textScale > 1.3;

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    shareButton,
                    const SizedBox(height: AppSpacing.sm),
                    homeButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: shareButton),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: homeButton),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// A compact, itemized "Coins earned" card: a bold total, then one row per
/// non-zero [CoinRewardBreakdown] line (e.g. "Medium win +15", "No-hint
/// bonus +5", "Daily Challenge bonus +10") — never a line for a
/// [CoinRewardBreakdown] field that is `0`. The caller ([_CompletedGameView])
/// never builds this widget at all for a `null`/non-rewarding breakdown, so
/// this card itself never has to represent "nothing earned".
///
/// Every number is communicated as text — never by color alone — matching
/// this project's accessibility baseline (see CLAUDE.md); the gold accent
/// on the total is a decoration on top of that text, not a substitute for
/// it. A single [Semantics] label reads the whole card as one sentence
/// (total, then each line), and the underlying row widgets are excluded
/// from the semantics tree so a screen reader never also reads each row a
/// second time individually.
class _CoinRewardBreakdownCard extends StatelessWidget {
  const _CoinRewardBreakdownCard({
    required this.breakdown,
    required this.difficulty,
  });

  final CoinRewardBreakdown breakdown;
  final GameDifficulty difficulty;

  List<(String label, int amount)> get _lines => [
    if (breakdown.baseWinReward > 0)
      ('${_difficultyLabel(difficulty)} win', breakdown.baseWinReward),
    if (breakdown.noHintBonus > 0) ('No-hint bonus', breakdown.noHintBonus),
    if (breakdown.dailyChallengeBonus > 0)
      ('Daily Challenge bonus', breakdown.dailyChallengeBonus),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final coinAccent = statusColors?.success ?? colorScheme.primary;
    final lines = _lines;

    final semanticsLabel = StringBuffer(
      'Coins earned: +${breakdown.totalCoinsEarned}.',
    );
    for (final (label, amount) in lines) {
      semanticsLabel.write(' $label: +$amount.');
    }

    return Semantics(
      label: semanticsLabel.toString(),
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.paid, color: coinAccent, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text('Coins earned', style: textTheme.titleMedium),
                    ),
                    Text(
                      '+${breakdown.totalCoinsEarned}',
                      style: textTheme.titleMedium?.copyWith(
                        color: coinAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                for (final (label, amount) in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text('+$amount', style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An explicit "this replay earned no additional coins" notice, shown only
/// for a Daily Challenge completion that was not today's official (first)
/// attempt — see [GameScreen.dailyChallengeReplayFeedback]'s own doc for why
/// this can't simply be inferred from [CoinRewardBreakdown] being absent (a
/// loss, official or not, is also absent a coin-reward card).
class _DailyChallengeReplayNotice extends StatelessWidget {
  const _DailyChallengeReplayNotice();

  static const String _text =
      'Daily Challenge replay: this attempt does not earn additional '
      'coins. Only your first attempt each day is official.';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: _text,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.replay, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows what happened to the streak as a result of a completed game:
/// "Streak started: 1 day", "Streak extended: 4 days", or "Today already
/// counted · 4-day streak".
///
/// A newly-started or newly-extended streak plays a restrained, one-time
/// fade+scale entrance animation, keyed by [animationKey] (the specific
/// [GameCompleted] instance this feedback belongs to) so the animation never
/// replays on an unrelated rebuild that leaves [animationKey] unchanged —
/// only a genuinely new completion (a new [GameCompleted] instance) can ever
/// retrigger it. "Already counted" today never animates — see the
/// milestone's own "do not trigger streak feedback when the same day was
/// already counted" rule; any haptic for a genuine start/extend is fired
/// once by the app-level composition root at the moment of completion, not
/// by this purely-visual widget.
class _StreakFeedbackBanner extends StatelessWidget {
  const _StreakFeedbackBanner({
    required this.feedback,
    required this.animationKey,
  });

  final StreakFeedback feedback;
  final Object animationKey;

  String get _text {
    final days = feedback.currentStreak;
    final dayWord = days == 1 ? 'day' : 'days';
    return switch (feedback.kind) {
      StreakFeedbackKind.started => 'Streak started: $days $dayWord',
      StreakFeedbackKind.extended => 'Streak extended: $days $dayWord',
      StreakFeedbackKind.alreadyCounted =>
        'Today already counted · $days-day streak',
    };
  }

  bool get _isReward => feedback.kind != StreakFeedbackKind.alreadyCounted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final iconColor = _isReward
        ? (statusColors?.success ?? colorScheme.tertiary)
        : colorScheme.tertiary;
    final text = _text;

    final content = Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, size: 20, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );

    if (!_isReward) return content;

    return TweenAnimationBuilder<double>(
      key: ValueKey(animationKey),
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.durationFor(context, AppMotion.entrance),
      curve: AppMotion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.85 + (0.15 * t), child: child),
      ),
      child: content,
    );
  }
}

class _StartupFailureView extends StatelessWidget {
  const _StartupFailureView({
    required this.onRetry,
    required this.onReturnHome,
  });

  final VoidCallback onRetry;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            "We couldn't start the game. Please try again.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: 'Home',
                child: ExcludeSemantics(
                  child: OutlinedButton.icon(
                    onPressed: onReturnHome,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Home'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
