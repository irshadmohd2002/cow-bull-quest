# Android release signing

## App identity

- Application ID: `com.cowbullgame.app`
- Display name: Cow Bull
- Version: `1.0.0+1`

## Why release builds fail right now

`android/app/build.gradle.kts` requires a real local signing configuration
for release builds and never falls back to the debug key. Until you create
your own upload keystore and `android/key.properties` (below), `flutter
build apk --release` and `flutter build appbundle --release` will fail on
purpose with a message telling you what to do. This is intentional, not a
bug — it exists so a release build can never be silently signed with the
debug key.

Debug builds, `flutter analyze`, and `flutter test` are unaffected and do
not need any of the setup below.

## 1. Generate an upload keystore

Run this yourself, locally — do not run it from an automated agent, and
never paste the resulting password or file into chat:

```sh
keytool -genkey -v -keystore /path/outside/repo/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Store the resulting `.jks` file **outside this repository** (e.g. in your
home directory or a password manager–backed secrets folder), not under
`CowBullGame/`. Losing this file, or forgetting its passwords, means you
can no longer publish updates to an existing release of the app under the
same app listing — Google Play requires the same upload key for every
update. Back it up somewhere durable.

## 2. Create `android/key.properties`

Copy the example file and fill in your real values:

```sh
cp android/key.properties.example android/key.properties
```

`android/key.properties` and `*.jks`/`*.keystore` files are gitignored —
never commit them, and never paste their contents into Claude or any other
chat tool.

### Required properties

| Property        | Meaning                                                        |
|-----------------|-----------------------------------------------------------------|
| `storeFile`     | Absolute path to your upload keystore `.jks` file (outside the repo) |
| `storePassword` | Password for the keystore itself                                |
| `keyAlias`      | Alias of the signing key inside the keystore (e.g. `upload`)    |
| `keyPassword`   | Password for that specific key alias                            |

If `android/key.properties` is missing, or any of these four values is
missing or blank, the release build fails during configuration with a
message explaining what to fix — before any signing or packaging happens.

## 3. Build a signed release

```sh
flutter build apk --release
flutter build appbundle --release
```

Expected output:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

## 4. Verify the signature

```sh
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

or, with `keytool`:

```sh
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

Confirm the certificate matches your upload keystore's alias, not a debug
certificate.

## Keep secrets out of the repo and out of chat

Never commit, and never paste into Claude or any other assistant: your
keystore file, `android/key.properties`, or any store/key password. All are
gitignored at the repository root.
