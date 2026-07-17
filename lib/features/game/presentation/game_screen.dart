import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_motion.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_status_colors.dart';
import '../../../widgets/coin_balance_badge.dart';
import '../controllers/game_controller.dart';
import '../controllers/game_controller_state.dart';
import '../models/game_config.dart';
import '../models/game_difficulty.dart';
import '../models/game_status.dart';
import '../services/guess_validator.dart';
import 'widgets/game_status_panel.dart';
import 'widgets/guess_history.dart';
import 'widgets/guess_input.dart';
import 'widgets/hint_section.dart';

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
  const GameScreen({super.key, required this.controller, required this.config});

  /// The controller for this game flow. Owned by this screen.
  final GameController controller;

  /// The configuration this screen was started (and is restarted) with.
  final GameConfig config;

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

  void _handleReturnHome() => Navigator.of(context).pop();

  void _handleRetry() => unawaited(widget.controller.startGame(widget.config));

  void _handleRestart() {
    _guessTextController.clear();
    unawaited(widget.controller.restart());
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Cow Bull Quest'),
          actions: [
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
        onRestart: _handleRestart,
        onReturnHome: _handleReturnHome,
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
    required this.onRestart,
    required this.onReturnHome,
  });

  final GameCompleted state;

  /// The number of hints used in the game that just ended.
  final int hintsUsed;
  final VoidCallback onRestart;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    final won = session.status == GameStatus.won;
    final outcomeText = won ? 'You won!' : 'You lost';
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final outcomeColor = won
        ? (statusColors?.success ?? colorScheme.primary)
        : colorScheme.error;
    final outcomeIcon = won ? Icons.emoji_events : Icons.flag;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label:
              '$outcomeText. The secret word was ${session.secretWord}. '
              'Attempts used: ${session.attemptsUsed} of ${session.maxAttempts}. '
              'Hints used: $hintsUsed.',
          child: ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.durationFor(context, AppMotion.entrance),
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
                        child: Icon(outcomeIcon, size: 40, color: outcomeColor),
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
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: GuessHistory(guesses: session.guesses)),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReturnHome,
                icon: const Icon(Icons.home),
                label: const Text('Return to Home'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.replay),
                label: const Text('Restart'),
              ),
            ),
          ],
        ),
      ],
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
              OutlinedButton.icon(
                onPressed: onReturnHome,
                icon: const Icon(Icons.home),
                label: const Text('Return to Home'),
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
