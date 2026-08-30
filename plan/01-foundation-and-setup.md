# Phase 01 — Foundation & Project Setup

**Goal:** A running, empty-but-wired Flutter app on a real device/emulator, with Firebase attached, navigation shell in place, and CI green. Nothing game-specific yet — this is the skeleton everything else attaches to.

**Depends on:** nothing (first phase).
**Enables:** all other phases (Firebase project, package structure, CI).

## Deliverables

1. Flutter project at repo root, targeting Android (minSdk 26 / Android 8+, needed for LiteRT-LM compatibility) and iOS (deferred build target, but project structure present).
2. Firebase project created and linked (via `firebase` MCP tools / CLI), Spark plan confirmed.
3. FlutterFire configured: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_crashlytics`, `firebase_performance`.
4. App shell: bottom-nav or drawer with placeholder screens for Home, Character, Play, Multiplayer, Settings — using `go_router` for navigation.
5. Riverpod wired at app root (`ProviderScope`).
6. Local persistence: `drift` package configured with an empty database and a migration strategy stub.
7. CI: GitHub Actions (or equivalent) running `flutter analyze` + `flutter test` on push.
8. `.gitignore` covers `*.tflite`, model files, `google-services.json`/`GoogleService-Info.plist` handling (see security note below).

## Tasks

### 1. Scaffold the Flutter project
- Run `flutter create dnd_ai --org com.<yourdomain>.dndai --platforms android,ios`.
- Set Android `minSdkVersion` to 26 in `android/app/build.gradle` (LiteRT-LM's NNAPI/GPU delegate paths need modern Android; confirm exact floor once Phase 02 vendors the LiteRT-LM AAR — 26 is a safe starting point, revisit if the AAR requires higher).
- Confirm `flutter run` launches the default counter app on an emulator before touching anything else.

### 2. Create the Firebase project
- Use the `firebase` MCP server tools: `firebase_login` (if not already authenticated), `firebase_create_project`, `firebase_create_app` (Android + iOS apps), `firebase_get_sdk_config`.
- Verify the project is on the **Spark** plan (default for new projects — do not upgrade to Blaze; Phase 06 is designed around Spark limits).
- Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) via `firebase_get_sdk_config`; place in `android/app/` and `ios/Runner/` respectively.
- **Security note:** these config files are not secrets (they're client identifiers), but still keep them out of any public repo mirror unless you intend the project to be public — add a repo-level decision here, don't just default to committing.

### 3. Wire FlutterFire
- Add packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_crashlytics`, `firebase_performance` to `pubspec.yaml`.
- Run `flutterfire configure` to generate `lib/firebase_options.dart`.
- In `main.dart`, call `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` before `runApp`.
- Smoke test: read/write a throwaway document to Firestore from a debug button; confirm it appears in the Firebase console. Delete the test doc and the button once confirmed.

### 4. App shell and navigation
- Add `go_router`. Define routes: `/home`, `/character`, `/play`, `/multiplayer`, `/settings`.
- Each route renders a placeholder `Scaffold` with the screen name as title — real UI comes from Phase 07's design system.
- Add a persistent bottom navigation bar wrapping these five routes.

### 5. State management baseline
- Add `flutter_riverpod`. Wrap `MyApp` in `ProviderScope`.
- Create one real provider as a pattern example: `settingsProvider` (a `StateNotifierProvider` backed by `SharedPreferences` for things like "has the model been downloaded", "selected model tier E2B/E4B").

### 6. Local persistence baseline
- Add `drift` + `sqlite3_flutter_libs`. Define an empty `AppDatabase` with a `schemaVersion` of 1 and zero tables (tables arrive in Phase 04/05 with their owning feature).
- Confirm the DB opens without error on app start (log a line, don't crash silently).

### 7. CI
- Add `.github/workflows/ci.yml`: on push/PR, `flutter pub get`, `flutter analyze`, `flutter test`.
- Confirm it passes on the initial skeleton commit.

### 8. Crashlytics/Performance smoke test (full integration is Phase 08)
- At minimum, confirm `FirebaseCrashlytics.instance.recordFlutterFatalError` is wired as the `FlutterError.onError` handler and that a forced test crash appears in the Crashlytics console. Full custom traces and non-fatal logging are Phase 08's job — this phase just proves the pipe isn't broken.

## Acceptance criteria

- [ ] `flutter run` launches the app shell on a physical or emulated Android device with 5 navigable placeholder screens.
- [ ] A Firestore smoke-test write is visible in the Firebase console, then removed from code.
- [ ] A forced test crash appears in the Crashlytics console within a few minutes.
- [ ] CI is green on the initial commit.
- [ ] `drift` database opens without error.

## Key files

- `lib/main.dart` — app entry, Firebase init, `ProviderScope`, `MaterialApp.router`.
- `lib/app/router.dart` — `go_router` config.
- `lib/app/theme.dart` — placeholder theme (real theme comes from Phase 07).
- `lib/data/local/app_database.dart` — `drift` database.
- `lib/firebase_options.dart` — generated, do not hand-edit.
