# Sharing a completed game result

How a player shares a finished game (win or loss), and the rules that keep
what gets shared privacy-safe.

## Package choice

Sharing uses [`share_plus`](https://pub.dev/packages/share_plus), pinned to
`13.2.1` in `pubspec.yaml`. It is the maintained, widely-used wrapper around
each platform's native system share sheet (`ACTION_SEND` on Android,
`UIActivityViewController` on iOS) and requires no extra Android permissions
— `ACTION_SEND` is a normal, unprivileged intent, so this feature adds no new
entries to `android/app/src/main/AndroidManifest.xml`.

There is **no direct integration with any specific app** (WhatsApp, etc.):
the system share sheet alone decides which installed apps are offered, and
the player picks one (or none). There is no login requirement anywhere in
this flow.

## Architecture

- `lib/core/sharing/result_share_service.dart` — the `ResultShareService`
  interface: `shareText({required String text, String? subject})`. App code
  depends on this interface, never on `package:share_plus` directly.
- `lib/core/sharing/share_plus_result_share_service.dart` —
  `SharePlusResultShareService`, the real implementation, wrapping
  `SharePlus.instance.share(ShareParams(...))`.
- `lib/features/game/services/game_result_share_formatter.dart` —
  `GameResultShareFormatter`: pure, deterministic text formatting for a
  completed `GameSession`. No platform calls, no Flutter imports.
- `lib/features/game/presentation/game_screen.dart` — the completed-game
  screen's "Share Result" and "Copy Result" actions call the formatter, then
  hand the resulting text to the injected `ResultShareService`
  (`Clipboard.setData` directly for Copy Result — no extra package needed for
  that).
- `test/support/fake_result_share_service.dart` — the in-memory fake used by
  widget tests, mirroring `FakeAudioService`/`FakeHapticService`.

`ResultShareService` is injected through the app's composition root
(`lib/app.dart`, `_CowBullAppState`), the same seam that already wires
`GameController`, audio, and haptics into each `GameScreen`.

## What the shared text contains — and never contains

`GameResultShareFormatter` never reads `GameSession.secretWord` or any
`Guess.word` — only each guess's turn number and its aggregate
`GuessResult.bulls`/`.cows`. `GuessResult` stores aggregate counts only (no
per-letter/per-position outcome), so the formatter renders one honest
`Guess N: 🟩 X Bull(s) · 🟨 Y Cow(s)` line per guess rather than fabricating
Wordle-style per-position tiles it has no data to back up. The scoring
algorithm itself (`GuessScorer`) is untouched — this is a text-formatting
concern only.

Also never included: coin balance, hints beyond a plain count, user
identity, device data, internal IDs, debug/error details, or a Play Store
link (no public listing URL exists yet).

A hint's *outcome* (letters/positions) is never in the shared text either —
only the total number of hints used this game, shown as `N hint(s) used`
when greater than zero.
