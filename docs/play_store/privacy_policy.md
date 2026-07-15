# Privacy Policy — Cow Bull Quest

Status: **completed, published** — the content below is live at the public
policy URL and matches the in-app link and the Play Console declaration.

**Effective date:** 15 July 2026

**Developer / publisher:** Md Irshadullah Gharbi

**Support email:** unfilteredofficial2021@gmail.com

**Public policy URL:** https://irshadmohd2002.github.io/cow-bull-quest/privacy-policy/

---

## Summary

Cow Bull Quest ("the app") is a word-guessing puzzle game. This policy
explains what information the app does and does not handle.

- The app does not require you to create an account.
- The app does not contain ads.
- The app does not use analytics or tracking of any kind.
- The app does not collect, transmit, sell, or share personal data.
- The app does not communicate with any developer-operated server. All
  gameplay logic and word lists are bundled with the app and run entirely
  on your device.
- The app does not request camera, microphone, location, contacts, or
  broad file/storage permissions.
- No third-party advertising SDK or analytics SDK is included in the app.

## What the app stores, and where

Cow Bull Quest stores two kinds of information, **locally on your device
only**, using Android's standard app-local storage:

1. **Theme preference** — whether you've chosen the light theme, the dark
   theme, or to follow your system setting.
2. **Completed-game statistics** — aggregate counts of wins and losses,
   your current and best win streaks, a breakdown by word length and
   difficulty, and a bounded list of your most recent completed games
   (word length, difficulty, outcome, and number of attempts used).

**Secret words and guessed words are never included in this data.** Only
the outcome of a finished game (win or loss, word length, difficulty, and
attempt count) is recorded — never the secret word itself or any word you
typed as a guess.

None of this data leaves your device. It is not transmitted anywhere,
because the app has no network communication with any server.

## Your controls

- **Clear statistics:** the Statistics screen in the app has a "Clear
  statistics" action (with a confirmation step) that permanently deletes
  your win/loss history and recent-games list from the device. Your theme
  preference is not affected by this action.
- **Remove all app data:** you can remove all locally stored data at any
  time through Android's Settings app (Settings → Apps → Cow Bull Quest →
  Storage & cache → Clear storage), or by uninstalling the app entirely.
  Either action removes both the theme preference and the statistics data
  described above.

## Data retention

Because no data is transmitted to or stored by the developer, there is no
server-side retention period to disclose. Locally stored data (theme
preference and statistics) persists on your device only until you clear it
in-app, clear app storage in Android Settings, or uninstall the app.

## Deletion

To delete all data associated with the app, use either of the "Your
controls" options above. There is no account to delete and no server-side
copy of your data to request deletion of, because none exists.

## Children's privacy

Cow Bull Quest is a general-audience word puzzle and is not directed at
children. It does not knowingly collect personal information from anyone,
including children, because it does not collect personal information from
any user.

## Security

Because the app does not collect or transmit personal data, there is no
server-side data transmission or storage to secure. Locally stored data is
protected by the operating system's standard per-app storage sandboxing on
your device.

## Changes to this policy

This policy may be updated to reflect future changes to the app. Material
changes will be reflected in the effective date above, and the updated
policy will be published at the public policy URL above. Continued use of
the app after a change constitutes acceptance of the updated policy.

## Contact

Questions about this policy or the app's data practices can be sent to the
support email above: unfilteredofficial2021@gmail.com.

---

## Publishing requirement (do not skip)

**This Markdown file is the source draft.** Its content has been published
as a publicly accessible HTTPS webpage (not a PDF-only link, not a document
requiring sign-in) at:

```
https://irshadmohd2002.github.io/cow-bull-quest/privacy-policy/
```

This exact URL must be entered into both:

- Play Console's Store presence → Privacy policy field, and
- the in-app privacy policy surface (see the next section).

**These two URLs must match exactly, character for character.** A
mismatch — even a trailing-slash or `http`-vs-`https` difference — is a
Play Console policy violation, so re-verify both fields against each other
before submission.

## In-app privacy-policy requirement — implemented (Option A)

Google Play policy requires apps to make their privacy policy accessible
**from within the app itself**, in addition to the Play Console listing.

**This is now implemented.** The Settings screen
(`lib/features/settings/presentation/settings_screen.dart`) has a "Privacy
Policy" row ("View how Cow Bull Quest handles local data.") that opens the
configured URL in the platform browser via the official `url_launcher`
plugin. The URL itself is centralized in one place,
`lib/core/privacy_policy.dart`, so it is never hard-coded into more than
one widget.

**The row is now enabled.** `lib/core/privacy_policy.dart` defines:

```
https://irshadmohd2002.github.io/cow-bull-quest/privacy-policy/
```

which is the final, published production URL — not a placeholder. The
placeholder constant (`placeholderPrivacyPolicyUrl`,
`https://example.com/cow-bull-quest/privacy`) is kept in the same file only
so `isReleaseReadyPrivacyPolicyUrl()` and its tests can still recognize the
placeholder shape if it's ever reintroduced accidentally; it is no longer
what `privacyPolicyUrl` points to. `isReleaseReadyPrivacyPolicyUrl()`
confirms the configured URL is a well-formed, non-placeholder HTTPS URL,
which the app-level composition root (`lib/app.dart`) checks before
enabling the row — with this URL in place, that check now passes, so the
Settings row shows as enabled with the supporting text "View how Cow Bull
Quest handles local data." and opens the page in the platform browser. If
the platform reports the launch failed (or the launch throws), the app
shows a brief, friendly message rather than a raw error, and never crashes
or leaves the UI in a broken state.

**Before submission, still confirm:**

1. **This same URL must also be entered as Play Console's Store presence →
   Privacy policy URL, exactly** — the in-app link and the Play Console
   declaration must point to the identical published page, not two
   different URLs. See the warning in "Publishing requirement" above.
2. The published page at that URL is live and reachable (not a 404 or a
   sign-in wall).

This behavior — and that the configured URL is release-ready — is covered
by tests in `test/core/privacy_policy_test.dart`,
`test/features/settings/presentation/settings_screen_test.dart`, and
`test/app_test.dart` (see the "Privacy Policy composition" group).
