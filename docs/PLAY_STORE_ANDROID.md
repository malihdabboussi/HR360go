# Google Play — Android release (HR360 Go)

This document records how the Android app was prepared for Play Console upload and how to rebuild signed App Bundles.

## App identity

| Field | Value |
|-------|--------|
| Application ID / package | `com.hrs360.hrs360go` |
| Display name | `HR360 Go` |
| Version name / code | From `pubspec.yaml` `version: X.Y.Z+N` → name `X.Y.Z`, code `N` |
| First upload | `1.0.0+1` → versionName `1.0.0`, versionCode `1` |

Bump the `+N` build number for **every** new Play upload. Version name can stay the same only if Play allows it for that track; version code must always increase.

## Signing (upload key — not debug)

Release builds previously used the **debug** keystore. That is unsuitable for Play (and would permanently bind the app to a debug certificate if uploaded).

### What was created

| File | Purpose | Git |
|------|---------|-----|
| `android/upload-keystore.jks` | Upload keystore (RSA 2048, alias `upload`, ~25 years) | **Ignored** — never commit |
| `android/key.properties` | Passwords + alias + store path | **Ignored** — never commit |
| `android/key.properties.example` | Template for other machines | Committed |

Gradle loads `android/key.properties` and signs `release` with that keystore. If `key.properties` is missing, the **release** build fails with a clear error (it does **not** fall back to debug).

### Backup (critical)

Back up **both** `upload-keystore.jks` and `key.properties` (or the passwords) in a secure place (password manager / encrypted drive). Losing the upload key requires a Play Console upload-key reset and delays releases.

### Recreate on another machine

1. Copy `upload-keystore.jks` and `key.properties` into `android/`, **or**
2. Generate a new keystore only if this is a **new** Play app that has never had an upload key:

```bash
keytool -genkey -v \
  -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 9125 \
  -alias upload \
  -dname "CN=HR360 Go, OU=Mobile, O=HR360, L=Unknown, ST=Unknown, C=US"
```

3. Copy `android/key.properties.example` → `android/key.properties` and fill in passwords.

## Branding and packaging changes

- Package / namespace / `MainActivity` moved to `com.hrs360.hrs360go`
- Launcher label `HR360 Go`; `android:allowBackup="false"`
- Adaptive launcher icons generated from brand colors (`assets/images/ic_launcher*.png`) via `flutter_launcher_icons`
- Release: R8 minify + shrink resources (`android/app/proguard-rules.pro`)
- Removed unused `flutter_local_notifications` / `timezone` (they pulled notification permissions into the merged manifest)

## Production `.env` before you ship

`.env` is still bundled as a Flutter asset. For a Play build:

1. Set `API_BASE_URL` to an **HTTPS** URL (cleartext HTTP is blocked on modern Android).
2. Set real `AES_KEY_HEX` (and optional secrets) matching production.
3. After the listing exists, set:

```text
ANDROID_STORE_URL=https://play.google.com/store/apps/details?id=com.hrs360.hrs360go
```

See `.env.example`. Rebuild after any `.env` change.

## Build the Play artifact (AAB)

Requires **JDK 17+** (AGP 8.x). On this machine Flutter was pointed at Homebrew OpenJDK:

```bash
# if needed:
# flutter config --jdk-dir="/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
# export JAVA_HOME="/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home"

flutter build appbundle --release
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

Upload the **AAB**, not a raw APK, to Play Console (Production / Internal testing / Closed testing).

### Verify signing (optional)

```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

You should see the upload certificate `CN=HR360 Go` (not Android Debug). An “Invalid certificate chain” message from jarsigner is normal for a self-signed upload key.

If R8 fails with missing `com.google.android.play.core.*` classes, ensure `android/app/proguard-rules.pro` includes the `-dontwarn` rules for Play Core deferred components (already present in this repo).

## Play Console checklist (you still do this)

Play Console being “ready” is not enough until the listing and policies are complete:

1. Create the app with package `com.hrs360.hrs360go` (must match the AAB).
2. First AAB upload: Google Play App Signing stays on by default — Google holds the **app signing** key; your `upload-keystore.jks` is the **upload** key.
3. Store listing: title, short/full description, screenshots, feature graphic (1024×500), app icon (512×512).
4. Privacy policy URL (required for apps that use location / account data).
5. Data safety form: declare **location** (attendance check-in), app activity / identifiers as applicable; internet; notifications are used for check-out reminders (see 8).
6. Content rating questionnaire, target audience, news apps / COVID / etc. declarations as prompted.
7. Location permission: Play may ask for a video or description — attendance geolocation is the justification (see manifest comment).
8. **Background location (`ACCESS_BACKGROUND_LOCATION`, added 2026-10-15 for shift watch)**: Play requires the *Location permissions declaration* form plus a short video. Justification: "When the employer enables automatic check-out, HR360 Go monitors the employee's assigned work locations only while they are checked in, so it can notify them and check them out when they leave. Monitoring stops at check-out." The app asks for "Allow all the time" only when the company turned the feature on. Also update the Data safety form: location collected in the background (attendance), and notifications (`POST_NOTIFICATIONS`) are now used for check-out reminders.

## Regenerating launcher icons

```bash
dart run flutter_launcher_icons
```

Config lives under `flutter_launcher_icons:` in `pubspec.yaml`.

## Out of scope of the repo changes

- Hosting a privacy policy or writing store copy
- Production API hostname (set in `.env` before release build)
- iOS App Store
