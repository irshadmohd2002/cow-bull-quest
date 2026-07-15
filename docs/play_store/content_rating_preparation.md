# Content rating preparation — IARC questionnaire

Status: **completed draft.** This document describes the likely factual
answers based on the app's actual implementation. **The final content
rating is assigned by the IARC questionnaire process and the relevant
rating authorities, not by this document** — treat every answer below as
preparation, to be re-confirmed against the exact questions Play Console's
questionnaire asks at submission time.

## Likely factual answers

| Questionnaire theme | Likely answer | Basis |
|---|---|---|
| Violence (any depiction) | No | The app has no graphics, characters, or narrative content beyond text and simple UI — see `lib/features/*/presentation/` |
| Sexual content | No | No such content exists anywhere in the app |
| Profanity / crude language | No | All in-app text is UI copy the developer wrote; guessable secret words are drawn from filtered dictionary word lists (`assets/generated/`, built per `docs/word_lists.md`), not user-submitted or profane content |
| References to drugs, alcohol, or tobacco | No | Not present in any app text or word lists |
| Gambling (real or simulated) | No | The app has no wagering, loot mechanics, or chance-based rewards; it is a pure word-deduction puzzle |
| User interaction (chat, messaging) | No | The app has no networking, messaging, or multiplayer feature — see Part 1 audit |
| User-generated content shared with others | No | No content a user creates is ever shared with other users; there is no sharing feature at all |
| Location sharing | No | The app requests no location permission and has no location feature |
| In-app purchases | No | Confirmed in `pubspec.yaml` — no purchase/billing dependency |
| Fear or horror themes | No | Not present |
| Realistic or unrestricted violence toward animals or people | No | Not present |
| Unrestricted web access / browser | No | The app embeds no web browser and has no network communication in release builds |

## Notes for whoever completes the questionnaire

- Answer strictly based on what the shipped app does, not on hypothetical
  future features.
- If the questionnaire asks about "user-generated content" in the sense of
  locally-created content (e.g. player statistics), note that this data is
  never shared with or visible to any other user or the developer — it
  stays local to the device (see `privacy_policy.md`).
- If a question's wording doesn't map cleanly onto anything in this table,
  answer it directly from the app's actual behavior rather than by
  analogy to this document.

## Disclaimer

This document does not assign, predict with certainty, or substitute for
the actual content rating. The final rating is determined by IARC's
questionnaire logic and the participating rating authorities (e.g. ESRB,
PEGI, USK) once the questionnaire is submitted in Play Console.
