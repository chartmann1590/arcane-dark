# Building a signed release

Two machine-local, **gitignored** files carry the secrets a release build needs.
Neither is committed; a plain `flutter run`/`flutter build` without them still
works (falls back to debug signing and Google's public test AdMob IDs).

## 1. Release signing — `android/key.properties`

```properties
storePassword=...
keyPassword=...
keyAlias=key0
storeFile=upload-keystore.jks
```

`storeFile` is relative to `android/app/`, where `upload-keystore.jks` lives
(also gitignored). `android/app/build.gradle.kts` reads this file and signs
the `release` build type with it; without it, release builds fall back to the
debug key (fine for local testing, **not accepted by Google Play**).

## 2. AdMob App ID (native manifest) — `android/admob.properties`

```properties
admobAppId=ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX
```

Injected into `AndroidManifest.xml`'s `com.google.android.gms.ads.APPLICATION_ID`
meta-data via a Gradle manifest placeholder. Without this file, the manifest
falls back to Google's public test App ID.

## 3. AdMob ad unit IDs (Dart) — `admob-config.json`

Copy `admob-config.example.json` to `admob-config.json` and fill in the real
values from your AdMob console (see `lib/services/ad_config.dart`). Build with:

```sh
flutter build appbundle --release --dart-define-from-file=admob-config.json
```

Omitting `--dart-define-from-file` (or omitting the file) keeps `AdConfig.useTestAds`
`true`, so ads always serve Google's safe test creatives.

## CI (GitHub Actions)

If/when a release workflow is added, store the same values as GitHub
**repository secrets** (e.g. `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ADMOB_APP_ID`, `ADMOB_BANNER_ID`,
`ADMOB_INTERSTITIAL_ID`) and have the workflow write `android/key.properties`,
`android/admob.properties`, and `admob-config.json` from those secrets at build
time — never commit the generated files, and add a step to delete them after
the build artifact is uploaded.
