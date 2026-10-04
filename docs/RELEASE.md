# Releasing to Google Play

The code side is ready: CI builds a release Android App Bundle (`.aab`)
with R8 shrinking, obfuscation, target SDK from Flutter 3.47, and a version
code that increases on every run. What's left needs the owner's accounts and
decisions.

## 1. Things only the owner can provide

| Item | Where it goes | Notes |
| --- | --- | --- |
| Google Play developer account | play.google.com/console | One-time $25 fee. New personal accounts must run a closed test before production (12 testers for 14 days at last check; confirm in the Console). |
| Final app name | `android:label` in `android/app/src/main/AndroidManifest.xml`, `title` in `lib/app.dart`, store listing | Working name is "Brightday". Check the name is free on Play and not trademarked. |
| Package id | `applicationId` and `namespace` in `android/app/build.gradle.kts`, Kotlin folder `android/app/src/main/kotlin/...` | Working id is `com.brightday.planner`. **Permanent after the first upload.** |
| Upload keystore | GitHub secrets (below) | Create once, back it up somewhere safe. |
| Privacy policy URL | Play Console + `PRIVACY_POLICY_URL` repository variable | Required because the app can send task text to the AI service. Template: [PRIVACY_POLICY.md](PRIVACY_POLICY.md). |
| Support email | Play Console + `SUPPORT_EMAIL` repository variable | |
| Anthropic API key | `proxy/` Worker secret | Only for AI breakdown. Without it the app uses offline suggestions. |
| Cloudflare account | Hosts `proxy/` | Free tier is enough to start. |
| Phone screenshots | Play listing | At least 2, 1080×1920 or similar. Take them from a real device or emulator. |

## 2. Create the upload keystore

```sh
keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
base64 -w0 upload.jks > upload.jks.b64
```

Add GitHub repository **secrets** (Settings → Secrets and variables → Actions):

- `ANDROID_KEYSTORE_BASE64` – contents of `upload.jks.b64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS` – `upload`
- `ANDROID_KEY_PASSWORD`
- `BREAKDOWN_API_TOKEN` – the same random string set as `APP_TOKEN` on the Worker

And repository **variables**:

- `BREAKDOWN_API_URL` – e.g. `https://brightday-breakdown.<you>.workers.dev/breakdown`
- `PRIVACY_POLICY_URL`
- `SUPPORT_EMAIL`

For local release builds, create `android/key.properties` (git-ignored):

```properties
storeFile=/absolute/path/to/upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Enrol in **Play App Signing** when you create the app (the default). Google
then holds the real app signing key and your keystore is only the upload key.

## 3. Build

Push to `main` (or run the CI workflow manually). Download the
`brightday-release-N` artifact; it contains `app-release.aab` plus test APKs
and the debug symbols folder.

Locally:

```sh
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/debug-info \
  --dart-define=BREAKDOWN_API_URL=... \
  --dart-define=BREAKDOWN_API_TOKEN=... \
  --dart-define=PRIVACY_POLICY_URL=... \
  --dart-define=SUPPORT_EMAIL=...
```

## 4. Play Console checklist

1. Create app → name, default language, App, Free.
2. **Store listing**: copy text from [`store/listing.md`](../store/listing.md);
   upload `store/icon-512.png` and `store/feature-graphic-1024x500.png`;
   add screenshots.
3. **App content**:
   - Privacy policy: your URL.
   - Ads: No.
   - App access: All functionality available without special access.
   - Content rating questionnaire: Productivity / utility, no
     objectionable content. Expected rating: Everyone.
   - Target audience: 18+ is simplest (13+ is fine too; avoid "under 13",
     which brings Families policy requirements).
   - Health apps declaration: describe it as a productivity / planning app.
     It does not diagnose or treat ADHD; don't claim medical benefits in the
     listing.
   - Data safety: answers in [`store/listing.md`](../store/listing.md#data-safety-form).
4. **Testing → Closed testing**: upload the `.aab`, add testers, run the
   required closed test (new personal accounts).
5. **Production**: promote the tested release, choose countries, submit for
   review.

## 5. Each new version

Bump `version:` in `pubspec.yaml` (the part before `+`) for the user-visible
version. CI sets the build number automatically from the run number, so
every bundle can be uploaded.
