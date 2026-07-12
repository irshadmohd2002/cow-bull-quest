import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../controllers/game_controller_state.dart';
import '../models/game_config.dart';
import '../models/game_status.dart';
import '../services/guess_validator.dart';
import 'widgets/game_status_panel.dart';
import 'widgets/guess_history.dart';
import 'widgets/guess_input.dart';

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
    case GuessValidationFailure.gameAlreadyWon:
      return 'You already won this game.';
    case GuessValidationFailure.gameAlreadyLost:
      return 'This game has already ended.';
  }
}

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

    _submitting = true;
    widget.controller.submitGuess(text);
    _submitting = false;

    final state = widget.controller.state;
    if (state is GameActive) {
      if (state.lastRejection == null) {
        _guessTextController.clear();
      } else {
        _guessTextController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _guessTextController.text.length,
        );
      }
      _guessFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bulls & Cows · ${widget.config.wordLength} letters'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => _buildBody(widget.controller.state),
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
        onSubmit: _handleSubmit,
      ),
      GameCompleted() => _CompletedGameView(
        state: state,
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Selecting a secret word...'),
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
    required this.onSubmit,
  });

  final GameActive state;
  final TextEditingController guessTextController;
  final FocusNode guessFocusNode;
  final int wordLength;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final rejection = state.lastRejection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameStatusPanel(view: state.view),
        const SizedBox(height: 16),
        Expanded(child: GuessHistory(guesses: state.view.guesses)),
        const SizedBox(height: 16),
        GuessInput(
          controller: guessTextController,
          focusNode: guessFocusNode,
          wordLength: wordLength,
          enabled: true,
          errorText: rejection == null
              ? null
              : _validationMessage(rejection, wordLength),
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

class _CompletedGameView extends StatelessWidget {
  const _CompletedGameView({
    required this.state,
    required this.onRestart,
    required this.onReturnHome,
  });

  final GameCompleted state;
  final VoidCallback onRestart;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    final won = session.status == GameStatus.won;
    final outcomeText = won ? 'You won!' : 'You lost';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label:
              '$outcomeText. The secret word was ${session.secretWord}. '
              'Attempts used: ${session.attemptsUsed} of ${session.maxAttempts}.',
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(won ? Icons.emoji_events : Icons.flag),
                      const SizedBox(width: 8),
                      Text(
                        outcomeText,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Secret word: ${session.secretWord.toUpperCase()}'),
                  Text(
                    'Attempts used: ${session.attemptsUsed} / '
                    '${session.maxAttempts}',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: GuessHistory(guesses: session.guesses)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReturnHome,
                child: const Text('Return to Home'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onRestart,
                child: const Text('Restart'),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text(
            "We couldn't start the game. Please try again.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: onReturnHome,
                child: const Text('Return to Home'),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ],
      ),
    );
  }
}
