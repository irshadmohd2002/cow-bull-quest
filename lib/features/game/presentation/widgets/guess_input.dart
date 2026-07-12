import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

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
class GuessInput extends StatelessWidget {
  const GuessInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.wordLength,
    required this.enabled,
    required this.hasError,
    required this.onSubmit,
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

  void _handleSubmit() => onSubmit(controller.text);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorBorder = hasError
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          )
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            label: 'Guess input, $wordLength letters',
            textField: true,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              maxLength: wordLength,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                const _UpperCaseTextFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Your guess',
                enabledBorder: errorBorder,
                focusedBorder: errorBorder,
              ),
              onSubmitted: enabled ? (_) => _handleSubmit() : null,
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
              onPressed: enabled ? _handleSubmit : null,
              child: const Text('Submit'),
            ),
          ),
        ),
      ],
    );
  }
}
