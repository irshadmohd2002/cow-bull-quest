# Cow Bull Quest — branding guide

## Identity

| Field | Value |
|---|---|
| App name (customer-facing) | Cow Bull Quest |
| Application ID | `com.cowbullgame.app` |
| Android namespace | `com.cowbullgame.app` |
| Version | `1.0.0+1` |

This app is unrelated to Tricent or any other company. No third-party
company identity appears anywhere in the app, its resources, or its store
assets.

## Asset sources

| Purpose | Path |
|---|---|
| Approved launcher-icon source (1254×1254, RGB) | `assets/branding/cow_bull_quest_icon.png` |
| UI mood-board reference (**not a runtime asset**) | `docs/design/cow_bull_quest_ui_mockup.png` |
| Play Store listing icon (512×512) | `docs/play_store/assets/cow_bull_quest_store_icon_512.png` |

`docs/design/cow_bull_quest_ui_mockup.png` is reference-only: its palette,
mood, and component styling informed this guide, but it is never bundled as
a Flutter asset and none of its extra features (coins, daily quests,
leaderboard, achievements, profiles, adventure mode, bottom navigation) were
implemented — those exist only in the mockup, not in this app.

## Final palette

Every pair below was checked against the WCAG contrast formula: body-text
pairs clear 4.5:1, large-text/icon/UI-outline pairs clear 3:1. Gold is never
used as body text on a light surface.

### Dark theme (most faithful to the icon)

| Role | Hex | Notes |
|---|---|---|
| `background` | `#0B1026` | Darkest navy |
| `surface` | `#121A33` | Navy surface |
| `surfaceContainerHighest` | `#1A2650` | Elevated navy/royal-blue |
| `primary` / `onPrimary` | `#FFC33D` / `#0B1026` | Brand gold action color |
| `secondary` / `onSecondary` | `#2F5FC4` / `#F5F1E6` | Royal blue |
| `tertiary` / `onTertiary` | `#2EC6FF` / `#072033` | Cyan |
| `error` / `onError` | `#FF6B6B` / `#1A0000` | Distinct hue from gold |
| success / onSuccess (`AppStatusColors`) | `#34C77B` / `#03170C` | Win state |
| `onSurface` | `#F5F1E6` | Warm white |
| `onSurfaceVariant` | `#A9B7D6` | Muted blue-grey |

### Light theme

| Role | Hex | Notes |
|---|---|---|
| `background` | `#FAF7F1` | Warm near-white |
| `surface` | `#FFFFFF` | |
| `surfaceContainerHighest` | `#EEF2FB` | Cool light blue tint |
| `primary` / `onPrimary` | `#FFC33D` / `#241900` | Same brand gold, dark text on it |
| `secondary` / `onSecondary` | `#153B8C` / `#FFFFFF` | Royal blue |
| `tertiary` / `onTertiary` | `#0A7EA8` / `#FFFFFF` | Deepened cyan (legible on white) |
| `error` / `onError` | `#C62828` / `#FFFFFF` | Distinct hue from gold |
| success / onSuccess (`AppStatusColors`) | `#1E7A46` / `#FFFFFF` | Win state |
| `onSurface` | `#14213D` | Navy-charcoal body text |
| `onSurfaceVariant` | `#5B6B8C` | Muted blue-grey |

Defined in `lib/theme/app_theme.dart` (`AppTheme.light` / `AppTheme.dark`)
and `lib/theme/app_status_colors.dart` (the one small `ThemeExtension`
added, since Material 3's `ColorScheme` has no "success" role).

## ColorScheme role mapping

- **Primary (gold)** — the single primary action per screen: Start Game,
  Submit guess, Retry. Never used as body text on a light background.
- **Secondary (royal blue)** — secondary actions (How to Play, Settings,
  Reset local data) and one of the two Bulls/Cows badge colors.
- **Tertiary (cyan)** — informational accents and the other Bulls/Cows
  badge color.
- **Success / error** — win vs. loss only; error is also used for
  validation/failure banners. Never confused with gold.

## Splash

Deep navy (`#0B1026`, `values/colors.xml` → `splash_background`) background
with the centered, unstretched adaptive-icon foreground emblem, no text.
Same navy is used for both system light and dark mode to avoid any
light/dark mismatch flash. Android 12+ uses the native
`windowSplashScreenBackground`/`windowSplashScreenAnimatedIcon` theme
attributes (`values-v31/styles.xml`) — no `androidx.core:core-splashscreen`
dependency was added. Pre-12 uses `drawable/launch_background.xml` /
`drawable-v21/launch_background.xml`. No artificial delay anywhere.

## Typography, corner radius, spacing

No new type scale — Material 3's default `TextTheme` via `ThemeData`, sized
by the existing `AppSpacing` tokens (`lib/theme/app_spacing.dart`, 4/8/12/
16/24/32). Corner radius is a single shared `12` (`AppTheme._cornerRadius`)
applied to cards, inputs, and buttons; chips use `8`. Cards use elevation
`1` plus a subtle `outlineVariant` border rather than heavier shadows.

## Primary/secondary action rules

- Exactly one gold `FilledButton` per screen for the primary action.
- `OutlinedButton`/`TextButton` are tinted `secondary` (blue) app-wide via
  the shared component theme, so every secondary action reads as blue
  without per-widget overrides.
- Destructive actions (Reset local data, Clear statistics) stay
  `OutlinedButton`/error-colored dialog actions — never gold.

## Bulls/Cows styling rules

Bulls and Cows are always conveyed as **text + a distinct icon + a distinct
accessible color** — never color alone:

- Bulls: `Icons.gps_fixed`, cyan (`tertiaryContainer`/`onTertiaryContainer`).
- Cows: `Icons.sync_alt`, blue (`secondaryContainer`/`onSecondaryContainer`).

This mapping is used identically in both the Game screen's guess-history
badges and the Rules screen's scoring explanation icons.

## Light-theme guidance

Bright, clean, near-white background; blue for primary surfaces (AppBar/
Card tinting); gold reserved for primary actions/highlights, never plain
body text; navy-charcoal (`#14213D`) for body text, not pure black.

## Dark-theme guidance

Deepest navy background, elevated navy/royal-blue surfaces, gold primary
actions, cyan secondary accents, warm white text — the palette closest to
the approved icon.

## Accessibility rules

- All role pairs meet WCAG contrast minimums (4.5:1 text, 3:1 large
  text/icons/outlines) — see the palette table above.
- Gold is never used as body text on a light/white surface.
- Bulls/Cows and win/loss are always text + icon + color, never color alone.
- Every interactive control keeps a 48×48 minimum tap target
  (`IconButtonTheme`, button `minimumSize`s).
- `Semantics` labels/tooltips are present on every icon-only element,
  including the new Home-screen emblem icon and Settings theme icons.
- 320×568 narrow layouts and 3× text scaling remain overflow-free (enforced
  by existing `does not overflow on a narrow screen` / `does not throw
  under large text scaling` tests on every screen).
- Reduced-motion (`MediaQuery.disableAnimationsOf`) behavior is unchanged —
  every animation still resolves through `AppMotion.durationFor`.

## Prohibited uses

- No Tricent branding, and no other company branding unless separately
  approved.
- No text inside the launcher icon.
- No fake Play Store badges, rankings, or awards.
- No AI claims.
- No daily quests, coins, rewards, hints, leaderboard, achievements, or
  profiles — these appear only in the reference mood board, never in the
  shipped app.
- No feature claims for functionality not actually present in the app.
