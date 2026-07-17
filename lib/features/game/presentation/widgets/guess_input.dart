import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_motion.dart';
import '../../../../theme/app_spacing.dart';

/// Uppercases whatever the player types, purely for display — the domain
/// layer normalizes case on its own, so this is a visual affordance only.
class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// The text field and submit action for entering one guess.
///
/// Restricts input to alphabetic characters and [wordLength] characters as a
/// usability affordance only — [GuessValidator] remains the sole source of
/// truth for whether a guess is actually valid, so this widget never
/// duplicates its rules beyond basic keystroke filtering.
///
/// Controlled from the outside: [controller] and [focusNode] are owned by
/// the parent (typically the gameplay screen) so it can clear the field
/// after an accepted guess or select its text after a rejected one. The
/// submit button additionally disables itself whenever the field is blank —
/// a UI-only affordance to avoid pointless taps, not a duplicate of domain
/// validation, which always remains authoritative.
class GuessInput extends StatefulWidget {
  const GuessInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.wordLength,
    required this.enabled,
    required this.hasError,
    required this.onSubmit,
    this.rejectionSignal = 0,
  });

  /// The text field's controller; owned by the caller.
  final TextEditingController controller;

  /// The text field's focus node; owned by the caller.
  final FocusNode focusNode;

  /// The secret word's length: caps input length and labels the field.
  final int wordLength;

  /// Whether submission is currently allowed (false while loading, once the
  /// game has ended, or while a submission is being processed).
  final bool enabled;

  /// Whether the most recent submission was rejected — tints the field's
  /// border as a secondary (non-sole) visual cue. The human-facing message
  /// itself is shown by the caller, not duplicated here.
  final bool hasError;

  /// Called with the current field text when the player submits, via
  /// either the submit button or the keyboard's action button.
  final ValueChanged<String> onSubmit;

  /// Bumped by the caller (see `GameScreen`'s `_rejectionSequence`) on every
  /// rejected submission, including consecutive identical ones. A change in
  /// this value — and only a change — triggers the field's shake animation;
  /// a rapid double-submit of the same invalid text still visibly shakes
  /// again rather than silently no-opping, and a rapid double-tap cannot
  /// stack two overlapping shakes since each change simply restarts the one
  /// animation from its rest position.
  final int rejectionSignal;

  @override
  State<GuessInput> createState() => _GuessInputState();
}

class _GuessInputState extends State<GuessInput>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: AppMotion.shake,
  );

  @override
  void didUpdateWidget(GuessInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rejectionSignal != oldWidget.rejectionSignal) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _shakeController.value = 0;
      } else {
        _shakeController
          ..stop()
          ..forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleSubmit() => widget.onSubmit(widget.controller.text);

  /// A short, decaying horizontal shake: a few oscillations whose amplitude
  /// tapers to zero by the end of [t], so the field always comes to rest
  /// exactly where it started.
  double _shakeOffset(double t) => math.sin(t * 4 * math.pi) * 8 * (1 - t);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorBorder = widget.hasError
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          )
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) => Transform.translate(
              key: const ValueKey('guess-input-shake-transform'),
              offset: Offset(_shakeOffset(_shakeController.value), 0),
              child: child,
            ),
            child: Semantics(
              label: 'Guess input, ${widget.wordLength} letters',
              textField: true,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                maxLength: widget.wordLength,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                  const _UpperCaseTextFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'Your guess',
                  enabledBorder: errorBorder,
                  focusedBorder: errorBorder,
                ),
                onSubmitted: widget.enabled ? (_) => _handleSubmit() : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Semantics(
            button: true,
            label: 'Submit guess',
            child: FilledButton(
              onPressed: widget.enabled ? _handleSubmit : null,
              child: const Text('Submit'),
            ),
          ),
        ),
      ],
    );
  }
}
