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

/// Horizontal space reserved inside the field for its content padding and
/// border, kept on top of the measured letter width so the fitted text never
/// touches the field's edges.
const double _guessFieldHorizontalChrome = 40;

/// Floor below which the guess text never shrinks further — small enough to
/// always fit even extreme combinations of narrow width and text scale, but
/// still legible.
const double _minGuessFontSize = 10;

/// The largest font size, no larger than [baseStyle]'s own size, at which
/// [wordLength] worst-case-width letters render on one line within
/// [maxWidth] under [textScaler].
///
/// [TextField] has no child widget around just its visible text to wrap in a
/// `FittedBox`, so this measures with the same [TextPainter] machinery
/// `FittedBox` uses internally and feeds the result back in as an explicit
/// `style.fontSize` — a robust equivalent that leaves the field's own box
/// (border, height, decoration) untouched.
double _fittedGuessFontSize({
  required TextStyle baseStyle,
  required TextScaler textScaler,
  required double maxWidth,
  required int wordLength,
}) {
  final baseFontSize = baseStyle.fontSize ?? 16;
  if (!maxWidth.isFinite || wordLength <= 0) return baseFontSize;

  final available = maxWidth - _guessFieldHorizontalChrome;
  if (available <= 0) return _minGuessFontSize;

  double measureWidth(double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        // "W" is among the widest uppercase glyphs in most fonts; typed
        // text is always uppercased, so this is a safe worst case.
        text: 'W' * wordLength,
        style: baseStyle.copyWith(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return painter.width;
  }

  var fontSize = baseFontSize;
  var width = measureWidth(fontSize);
  if (width <= available) return baseFontSize;

  // Two passes: an initial proportional estimate, then one correction for
  // any non-linearity in the platform's TextScaler curve.
  for (var pass = 0; pass < 2 && width > available; pass++) {
    final scale = (available / width) * 0.97;
    fontSize = (fontSize * scale).clamp(_minGuessFontSize, baseFontSize);
    width = measureWidth(fontSize);
  }
  return fontSize;
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Material 3's own default TextField text style, so this
                  // measures (and renders) exactly what would have shown up
                  // if `style` were left unset — normal-width screens see no
                  // visual change, only narrow ones get a smaller font.
                  final baseStyle = Theme.of(context).textTheme.bodyLarge!;
                  final fontSize = _fittedGuessFontSize(
                    baseStyle: baseStyle,
                    textScaler: MediaQuery.textScalerOf(context),
                    maxWidth: constraints.maxWidth,
                    wordLength: widget.wordLength,
                  );
                  return TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    enabled: widget.enabled,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.text,
                    maxLines: 1,
                    minLines: 1,
                    maxLength: widget.wordLength,
                    style: baseStyle.copyWith(fontSize: fontSize),
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
                  );
                },
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
