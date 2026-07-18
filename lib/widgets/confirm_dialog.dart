import 'package:flutter/material.dart';

/// Shows a concise Yes/No confirmation dialog and returns whether the
/// player confirmed.
///
/// Shared by every destructive or progress-losing action that needs a
/// confirmation (leaving/restarting an active game, resetting local data —
/// see `app.dart`/`game_screen.dart`/`settings_screen.dart`), so the same
/// dialog shape, spacing, and theming is used everywhere one is needed
/// rather than each call site rebuilding its own [AlertDialog]. Returns
/// `false` — never `null` — for a dialog dismissed without an explicit
/// choice (e.g. tapping the scrim or the system back gesture), so every
/// caller can treat the result as a plain, non-nullable "did the player
/// confirm" boolean.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
