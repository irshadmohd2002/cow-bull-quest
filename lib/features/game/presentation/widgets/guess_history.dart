import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_motion.dart';
import '../../../../theme/app_spacing.dart';
import '../../models/guess.dart';
import 'guess_history_tile.dart';

/// The list of guesses made so far in a session.
///
/// Displayed newest-first: the most recent guess's feedback is what the
/// player needs to see next, and with attempt limits of up to 20 a
/// newest-first list keeps it visible without scrolling.
class GuessHistory extends StatefulWidget {
  const GuessHistory({
    super.key,
    required this.guesses,
    this.shrinkWrap = false,
  });

  /// The guesses made so far, oldest first (as produced by [GameSession]).
  final List<Guess> guesses;

  /// When `true`, sizes to its content and disables its own scrolling
  /// instead of requiring a bounded/flexible ancestor (e.g. `Expanded` or
  /// `SliverFillRemaining`) — for a caller that already places this widget
  /// inside its own scrollable region (see the completed-game screen) and
  /// would otherwise end up with two nested scrollables.
  final bool shrinkWrap;

  @override
  State<GuessHistory> createState() => _GuessHistoryState();
}

class _GuessHistoryState extends State<GuessHistory> {
  /// A fresh [GlobalKey] each time [_newestFirst] is reset outright (see
  /// [didUpdateWidget]) — forces [AnimatedList] to remount cleanly (e.g. on
  /// restart, when the guess list resets to empty) instead of trying to
  /// reconcile an unrelated new session against its old internal state.
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<Guess> _newestFirst;

  @override
  void initState() {
    super.initState();
    // Computed eagerly here — rather than as a `late` field initializer —
    // so it always reflects the widget this [State] was actually created
    // for. A `late` initializer instead evaluates lazily on first read,
    // which (when the very first read happens to be inside
    // [didUpdateWidget], e.g. because the initial empty-history render
    // never touches this field at all) would read the *already-updated*
    // [widget] rather than the one this state started with, double
    // counting the first appended guess.
    _newestFirst = widget.guesses.reversed.toList();
  }

  @override
  void didUpdateWidget(GuessHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldGuesses = oldWidget.guesses;
    final newGuesses = widget.guesses;
    final isSimpleAppend =
        newGuesses.length == oldGuesses.length + 1 &&
        listEquals(newGuesses.sublist(0, oldGuesses.length), oldGuesses);

    if (isSimpleAppend) {
      _newestFirst.insert(0, newGuesses.last);
      _listKey.currentState?.insertItem(
        0,
        duration: AppMotion.durationFor(context, AppMotion.entrance),
      );
    } else if (!listEquals(newGuesses, oldGuesses)) {
      // Any other change (most notably a restart, which resets guesses back
      // to empty) — resync without animating and remount the list fresh.
      setState(() {
        _newestFirst = newGuesses.reversed.toList();
        _listKey = GlobalKey<AnimatedListState>();
      });
    }
  }

  Widget _emptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Semantics(
        excludeSemantics: true,
        label: 'Enter any 4-letter word to start the game.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_edu_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Enter any 4-letter word to start the game.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.guesses.isEmpty) {
      // [shrinkWrap] callers already place this widget inside their own
      // scrollable, height-flexible region (see the completed-game screen),
      // so the empty state there just sizes to its content. The default
      // (non-shrinkWrap) caller wraps it in its own scrollable,
      // height-flexible container — rather than a bare Center — so this
      // empty-state message degrades to scrolling instead of a hard
      // overflow whenever the space available to it is small (e.g. a short
      // viewport combined with a large text-scale factor); on any
      // normal-sized viewport the content still fits entirely and simply
      // renders centered, unchanged from before.
      if (widget.shrinkWrap) return _emptyState(context);
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _emptyState(context),
          ),
        ),
      );
    }

    return AnimatedList(
      key: _listKey,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      initialItemCount: _newestFirst.length,
      itemBuilder: (context, index, animation) {
        // Items built as part of [AnimatedListState.insertItem] get a
        // real, ticking [animation]; items present from [initialItemCount]
        // get an always-completed one — so only a genuinely new guess ever
        // animates in, never the whole history on first mount.
        final guess = _newestFirst[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: FadeTransition(
            key: ValueKey('guess-entrance-fade-${guess.turnNumber}'),
            opacity: animation,
            // A FadeTransition otherwise excludes its child from the
            // semantics tree while opacity is 0 — i.e. for the entrance
            // animation's very first frame — which would make a screen
            // reader briefly skip a freshly-accepted guess entirely.
            alwaysIncludeSemantics: true,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(animation),
              child: GuessHistoryTile(guess: guess),
            ),
          ),
        );
      },
    );
  }
}
