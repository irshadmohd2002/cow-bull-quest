# Play Console declarations — draft for manual entry

Status: **completed draft, for manual entry only.** This document is not
legal advice and does not submit anything automatically. Every value below
must be manually re-entered (or re-verified) against the exact questions
shown in your own Play Console at submission time — question wording and
available options change over time and can differ by account/region.

## App classification

| Field | Draft value |
|---|---|
| App or game | Game |
| Category | Word or Puzzle (confirm exact label — Play Console's category list may show "Puzzle" and "Word" as separate categories; pick whichever single category is currently available and closest) |
| Contains ads | No |
| App access restrictions | None — the entire app is available without any login, paywall, or restricted content |
| Login required | No |
| Target audience | General audience; not primarily directed at children |

## Data Safety

| Field | Draft value |
|---|---|
| Data collected | None |
| Data shared with third parties | None |
| Data encrypted in transit | Not applicable — no data is transmitted |
| Users can request data deletion | Not applicable — no data is collected off-device; in-app "Clear statistics" and Android's own "Clear storage"/uninstall remove all local data (see `privacy_policy.md`) |
| Security practices claimed | None claimed beyond "no data collected" — do not check boxes for practices (e.g. "data is encrypted in transit") that don't apply when nothing is transmitted |

## Accounts and commerce

| Field | Draft value |
|---|---|
| Account creation | No |
| Account deletion | Not applicable (no accounts exist) |
| In-app purchases | No |
| Subscriptions | No |

## Content and audience flags

| Field | Draft value |
|---|---|
| Government affiliation | No |
| News app | No |
| Health app (COVID-19 or otherwise) | No |
| Financial features | No |
| Gambling / gambling-adjacent content | No |
| User-generated content | No |
| Location access | No |
| Sensitive permissions declared | None — release build requests no camera, microphone, location, contacts, or broad storage permission (see Part 1 audit) |

## Technical

| Field | Draft value |
|---|---|
| Offline capability | Yes — the app is fully playable with no network connection |
| Application ID | `com.cowbullgame.app` |
| Version | `1.0.0+1` |

## Contact and policy

| Field | Draft value |
|---|---|
| Privacy policy URL | `[PLACEHOLDER: public HTTPS URL — see privacy_policy.md]` |
| Support email | `[PLACEHOLDER: support email address]` |

## Warning

Every declaration above must be **manually re-verified against the final,
signed AAB** before submission (permissions and dependencies can change
between when this document is written and when the AAB is built), and
against **the exact questions and options shown in your own Play Console**,
since Google periodically changes question wording, available categories,
and Data Safety form structure. This document is a factual preparation
aid, not legal advice, and does not submit or validate anything in Play
Console on its own.
