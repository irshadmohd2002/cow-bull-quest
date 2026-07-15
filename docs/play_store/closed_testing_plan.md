# Closed testing plan — Cow Bull Quest

Status: **completed draft plan**. No Play Console actions have been
performed as part of producing this document — every step below is
still to be executed manually by the developer.

## Steps

1. **Create the app in Play Console** using application ID
   `com.cowbullgame.app`. Do not change the application ID — it must
   match the signed AAB exactly.
2. **Complete the app-content and policy sections** — Data Safety form,
   content rating questionnaire, target audience, ads declaration, and
   privacy policy URL — using the drafts in this `docs/play_store/`
   folder as source material, filled in with real values (see
   placeholders in `support_information.md` and `privacy_policy.md`).
3. **Upload the signed AAB to Internal testing first.** Use
   `docs/android_release_signing.md` to produce
   `build/app/outputs/bundle/release/app-release.aab` signed with your
   own upload keystore — never the debug key.
4. **Review device compatibility and generated APKs** in the release
   details Play Console produces from the AAB, checking for any
   unexpected device exclusions.
5. **Run the Play pre-launch report** and review the results (crashes,
   accessibility findings, security warnings) once available.
6. **Fix any release-blocking issues** found in steps 4-5 before
   proceeding, and re-upload a new build if changes were made.
7. **Create a Closed testing track**, if your Play Console setup
   requires a separate track from Internal testing (some account/app
   configurations allow going straight to Closed testing).
8. **Add testers** through an email list or a Google Group, per whichever
   Play Console currently supports for your track.
9. **Share the official opt-in link** Play Console generates for the
   Closed testing release — see `tester_instructions.md` for what to tell
   testers. Do not construct or guess this link manually; use the one
   Play Console provides.
10. **Collect structured feedback** using
    `docs/play_store/tester_feedback_template.md`.
11. **Upload a new build number** (incrementing the version code) for any
    fixes made in response to feedback, repeating steps 4-6 as needed.
12. **Maintain any tester-count and duration requirement** shown in your
    own Play Console for the account/app in question (see the note
    below).
13. **Apply for production access only** after every displayed
    requirement (testers, duration, and any outstanding policy items) is
    satisfied.

## Eligibility note — verify in your own Play Console

At the time of writing, newly created personal Google Play developer
accounts may be required to keep **at least 12 testers opted in
continuously for 14 days** in a closed test before becoming eligible to
apply for production access. **This exact requirement, and whether it
applies to your account, must be verified directly in your own Play
Console** — eligibility rules and thresholds are set by Google and can
change; do not rely on this document alone when planning your testing
timeline.

## Out of scope for this document

This plan does not perform any of the above steps — creating the Play
Console app entry, uploading builds, inviting testers, or applying for
production access all remain manual actions for the developer to carry
out directly in Play Console.
