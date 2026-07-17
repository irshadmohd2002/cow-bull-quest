# Audio assets

Where this app's sound effects and background music live, and the rule for
adding any more.

## Where assets live

- `assets/audio/sfx/` — short sound effects (`button_tap.mp3`,
  `invalid_guess.mp3`, `hint_used.mp3`, `coin_spent.mp3`, `win.mp3`,
  `loss.mp3`).
- `assets/audio/music/` — the background-music loop (`game_theme.mp3`).

Both directories are registered as asset directories in `pubspec.yaml`.

## Licensing

`docs/licenses/audio_licenses.md` is the source-of-truth record for every
bundled audio asset: original title, creator, source page, exact licence,
and whether commercial mobile-app use and attribution are required. It is
never described as "copyright-free" — check what the licence itself actually
grants before repeating any claim about it.

**Any new audio asset must have its licence recorded there, with commercial
mobile-app use confirmed, before it is bundled.** Do not add unlicensed
audio.

## Architecture

Playback and haptics are never called directly from widgets or
`GameController`. See:

- `lib/core/audio/audio_service.dart` — the `AudioService` interface.
- `lib/core/audio/audioplayers_audio_service.dart` — the real
  implementation, backed by `package:audioplayers`.
- `lib/core/haptics/haptic_service.dart` — the `HapticService` interface,
  backed by Flutter's built-in `HapticFeedback` (no separate haptics
  package).
- `lib/core/feedback/game_feedback.dart` — the narrow interface
  `GameController` reports gameplay outcomes through.
- `lib/audio_feedback_coordinator.dart` — the single place that maps a
  gameplay/UI event to specific sound/haptic calls, gated on
  `lib/audio_feedback_settings.dart`'s three independent, persisted
  preferences (sound effects, background music, haptics).

Tests use `test/support/fake_audio_service.dart`,
`test/support/fake_haptic_service.dart`, and
`test/support/fake_game_feedback.dart` — automated tests never play real
audio or trigger real device haptics.
