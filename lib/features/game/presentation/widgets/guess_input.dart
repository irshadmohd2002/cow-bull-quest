import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

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
/// after an accepted guess or select its text after a rejected one.
class GuessInput extends StatelessWidget {
  const GuessInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.wordLength,
    required this.enabled,
    required this.errorText,
    required this.onSubmit,
  });

  /// The text field's controller; owned by the caller.
  final TextEditingController controller;

  /// The text field's focus node; owned by the caller.
  final FocusNode focusNode;

  /// The secret word's length: caps input length and labels the field.
  final int wordLength;

  /// Whether submission is currently allowed (false while loading or once
  /// the game has ended).
  final bool enabled;

  /// Human-facing validation feedback for the most recent rejection, or
  /// `null` if the last submission was accepted or none has been made yet.
  final String? errorText;

  /// Called with the current field text when the player submits, via
  /// either the submit button or the keyboard's action button.
  final ValueChanged<String> onSubmit;

  void _handleSubmit() => onSubmit(controller.text);

  @override
  Widget build(BuildContext context) {
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
                errorText: errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: enabled ? (_) => _handleSubmit() : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 4),
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
