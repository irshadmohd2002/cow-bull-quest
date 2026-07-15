# Play Console checklist — Cow Bull Quest

Status: **completed checklist draft**, for manual use while working
through Play Console. Confirmed product values are pre-filled where the
checklist references them; placeholders remain for values only the
developer can supply.

## Confirmed values (reference while completing every section below)

- App name: **Cow Bull Quest**
- Application ID: **com.cowbullgame.app**
- Version: **1.0.0+1**
- Ads: **No**
- Account required: **No**
- In-app purchases: **No**
- Data collected or shared: **None**
- Sensitive permissions requested: **None**

## Placeholders to fill in before use

- Developer name: `[PLACEHOLDER]`
- Support email: `[PLACEHOLDER]`
- Privacy-policy URL: `[PLACEHOLDER]`
- Play Console account type (personal / organization): `[PLACEHOLDER]`
- Tester group (email list or Google Group name): `[PLACEHOLDER]`
- Country availability (which countries the app will be released in): `[PLACEHOLDER]`

## Developer-account setup

- [ ] Google Play Developer account created and registration fee paid
- [ ] Account type confirmed (personal / organization): `[PLACEHOLDER]`
- [ ] Developer identity/contact details verified with Google

## App creation

- [ ] New app created in Play Console
- [ ] Application ID set to `com.cowbullgame.app` (matches signed AAB)
- [ ] Default language set to English
- [ ] App name set to "Cow Bull Quest"

## Identity

- [ ] App name consistent everywhere: "Cow Bull Quest"
- [ ] No unrelated company branding anywhere in the listing (see
      `branding_guide.md`'s "Prohibited uses" section)

## Store listing

- [ ] Title copied from `store_listing.md` (14/30 characters)
- [ ] Short description copied from `store_listing.md` (49/80 characters)
- [ ] Full description copied from `store_listing.md` (1,640/4,000 characters)
- [ ] Category set to Word or Puzzle (or closest currently-available label)
- [ ] Contact details (support email) filled in: `[PLACEHOLDER]`

## Graphics

- [ ] App icon uploaded (512×512, from `docs/play_store/assets/cow_bull_quest_store_icon_512.png`)
- [ ] Feature graphic produced per `feature_graphic_brief.md` and uploaded (1024×500)
- [ ] Six phone screenshots captured per `screenshot_plan.md` and uploaded

## Privacy policy

- [ ] `privacy_policy.md` content published as a public HTTPS webpage
- [ ] Public URL entered in Play Console's privacy-policy field: `[PLACEHOLDER]`
- [x] In-app privacy-policy link implemented — Settings → "Privacy Policy"
      row (see `privacy_policy.md` "In-app privacy-policy requirement —
      implemented (Option A)")
- [ ] `lib/core/privacy_policy.dart`'s `privacyPolicyUrl` replaced with the
      final published URL (currently the documented placeholder, which
      keeps the Settings row disabled by design)
- [ ] Confirmed the in-app URL and the Play Console privacy-policy URL are
      the identical published page

## Data Safety

- [ ] Data Safety form completed using `play_console_declarations.md` as source
- [ ] "No data collected" / "No data shared" declared and consistent with the implementation audit

## Ads declaration

- [ ] "Contains ads: No" declared

## App access

- [ ] "App access restrictions: None" declared (entire app usable without login/paywall)

## Target audience

- [ ] Target audience set to general audience, not primarily directed at children
- [ ] Confirmed no child-directed content or COPPA-triggering features exist

## Content rating

- [ ] IARC questionnaire completed using `content_rating_preparation.md` as a factual reference
- [ ] Final assigned rating reviewed once returned by IARC

## Permissions

- [ ] Confirmed release manifest (`android/app/src/main/AndroidManifest.xml`) requests no camera, microphone, location, contacts, or broad storage permission
- [ ] Confirmed no `<uses-permission>` entries appear in the release build's merged manifest

## Release signing

- [ ] Upload keystore generated and stored securely outside the repository
- [ ] `android/key.properties` created locally (never committed) per `docs/android_release_signing.md`
- [ ] Signed AAB produced via `flutter build appbundle --release`
- [ ] Signature verified (not a debug certificate) via `apksigner verify --print-certs`

## App bundle

- [ ] `app-release.aab` built from a commit that matches what was tested
- [ ] Version code/name confirmed as `1.0.0+1` in the build output

## Internal testing

- [ ] AAB uploaded to Internal testing track first
- [ ] Internal testers confirmed install/launch successfully

## Pre-launch report

- [ ] Pre-launch report reviewed for crashes, accessibility issues, and security warnings
- [ ] Any blocking issues found resolved before proceeding

## Closed testing

- [ ] Closed testing track created (if separate from Internal)
- [ ] Testers added via email list or Google Group: `[PLACEHOLDER: tester group]`
- [ ] Opt-in link shared per `tester_instructions.md`
- [ ] Feedback collected via `tester_feedback_template.md`
- [ ] Country availability configured: `[PLACEHOLDER]`

## Production-access readiness

- [ ] Tester-count and duration requirement shown in your own Play Console satisfied (see `closed_testing_plan.md` eligibility note)
- [ ] All app-content/policy sections show no outstanding action items
- [ ] Production release only requested after every item above is satisfied
