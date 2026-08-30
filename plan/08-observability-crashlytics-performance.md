# Phase 08 — Observability (Crashlytics & Performance Monitoring)

**Goal:** Full crash reporting and performance tracing wired in — with the AI inference path and multiplayer sync specifically instrumented, since those are this app's two most likely sources of real-world failure (device OOM during inference, Firestore quota/sync issues).

**Depends on:** Phase 01 (Crashlytics smoke test already proved the pipe works), Phase 02 (inference calls to trace), Phase 06 (sync calls to trace).
**Enables:** Phase 09 (launch readiness needs real telemetry, not guesses).

## Deliverables

1. Crashlytics fully wired: fatal Flutter errors, fatal native (Android/Kotlin) errors from the LiteRT-LM platform channel, and deliberate non-fatal error logging at key failure points identified in Phases 02/03/05/06.
2. Performance Monitoring custom traces around: model load time, time-to-first-token, full generation time, map generation time, Firestore session-state round-trip time.
3. Custom keys/attributes on crash reports so a crash can be correlated with app state (which screen, which model tier E2B/E4B, RAM tier, whether in solo or multiplayer mode) without ever logging campaign/character content (privacy constraint from Phase 00).
4. A lightweight in-app "Send Diagnostics" action in Settings that forces a Crashlytics log flush + shows the user their device's RAM tier and current model — useful for support requests without needing remote debugging access.

## Tasks

### 1. Fatal error wiring (Dart side)
- Confirm/extend Phase 01's setup: `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;` and `PlatformDispatcher.instance.onError` forwarding for errors outside the Flutter error zone.

### 2. Fatal error wiring (native Android side)
- In the LiteRT-LM platform channel module (Phase 02), catch native exceptions (e.g. `OutOfMemoryError` during model load) and forward them to Crashlytics via the Android Crashlytics SDK (`FirebaseCrashlytics.getInstance().recordException(e)`) **before** the exception propagates back across the platform channel as a `PlatformException` — this ensures native OOM crashes are visible in the same Crashlytics dashboard as Dart crashes, not lost.

### 3. Non-fatal logging at known risk points
- Phase 02: model load failure, model timeout, checksum mismatch on download.
- Phase 03: DM engine failing to parse an action block twice in a row (the fallback path) — log as non-fatal, it indicates the model or prompt needs tuning.
- Phase 05: AI map-placement call failing and falling back to deterministic placement — log as non-fatal (silent fallbacks should still be visible in aggregate, or you'll never know how often the AI path is actually working in production).
- Phase 06: Firestore write/read failures, host-disconnect events, quota-warning threshold crossed.
- Use `FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: '...', fatal: false)` consistently, with a short enum-like `reason` string per site so these are groupable in the console.

### 4. Custom keys
- Set on app start / state change (not per-error, so they're always current when a crash happens):
  - `model_tier` (E2B/E4B/none-downloaded)
  - `device_ram_tier`
  - `session_mode` (solo/multiplayer-host/multiplayer-guest)
  - `current_screen` (updated on navigation)
- **Never** set campaign text, character names chosen by the player, or chat/action content as a custom key or log message — this violates the privacy constraint from Phase 00. Keep everything structural/technical.

### 5. Performance Monitoring custom traces
- Wrap in `lib/services/perf.dart` helper functions so call sites stay one-liners:
```dart
Future<T> traced<T>(String name, Future<T> Function() op) async {
  final trace = FirebasePerformance.instance.newTrace(name);
  await trace.start();
  try { return await op(); } finally { await trace.stop(); }
}
```
- Instrument: `model_load`, `model_generate_full`, `model_time_to_first_token` (custom metric set via `trace.setMetric` when the first stream event arrives, not just start/stop), `map_generation`, `firestore_state_roundtrip`.
- Confirm traces appear in the Firebase Performance console within the expected delay (can take a few hours to first appear — don't panic if it's not instant; verify via the debug logging Performance Monitoring provides in debug builds instead of waiting on the console for iteration).

### 6. In-app diagnostics action
- Settings screen button: "Send Diagnostics" — flushes pending Crashlytics reports (`FirebaseCrashlytics.instance.sendUnsentReports()`), and shows a bottom sheet with device RAM tier, selected model, app version, and a short "your feedback ID" (e.g. the last 8 chars of the installation ID) the user can quote in a support message.

## Acceptance criteria

- [ ] A forced native (Kotlin-side) exception during model load appears in Crashlytics with the same clarity as a Dart-side crash.
- [ ] Custom keys (model tier, RAM tier, session mode, screen) are visible on a test crash report in the Firebase console.
- [ ] All four listed custom traces (`model_load`, `model_generate_full`, `map_generation`, `firestore_state_roundtrip`) show up in the Performance console after a full manual playtest.
- [ ] No campaign/character content appears anywhere in a crash report or log (manual audit of a sample of logged events).
- [ ] "Send Diagnostics" button flushes reports and displays correct device info.

## Key files

- `lib/services/perf.dart`
- `lib/services/crash_reporting.dart` (thin wrapper around Crashlytics calls used at all the risk-point call sites above)
- `android/.../llm/LlmEngine.kt` (native exception forwarding, extends Phase 02's file)
- `lib/features/settings/settings_screen.dart` (diagnostics action)
