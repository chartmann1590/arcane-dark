# Phase 02 — On-Device AI Runtime (Gemma 4 / LiteRT-LM)

> **Status (2026-08-29): real native bridge implemented and verified end-to-end on a physical Pixel 8 Pro.** `android/.../LlmEngine.kt` + `MainActivity.kt` wire the actual `com.google.ai.edge.litertlm` Kotlin API (not a mock) via MethodChannel/EventChannel; `lib/services/model_inference_service.dart`'s `LiteRtModelInferenceService` calls it. `lib/services/model_download_manager.dart` does a real resumable Dio download + SHA-256 verification of the actual `litert-community/gemma-4-E2B-it-litert-lm` model (2.59GB CPU-backend `.litertlm` build — not the ~1.6-2GB figure originally estimated in this doc; downstream UI copy/manifests updated accordingly). Confirmed working: full download→checksum→native load→streamed generation produced coherent, real narration (not canned mock text) with TTFT ~2.8s / full response ~18s on a Pixel 8 Pro. Two real build issues were hit and fixed along the way — keep these fixes if bumping versions later: (1) Kotlin Gradle plugin had to move to 2.4.0 to read the AAR's metadata; (2) `kotlinx-coroutines-android` had to be forced to 1.11.0 (`resolutionStrategy.force` in `android/app/build.gradle.kts`) or the app crashes at runtime with `NoSuchMethodError` on `SendChannel.close$default` from a version conflict. `kotlin.incremental=false` is also set in `android/gradle.properties` to work around a Kotlin 2.4 incremental-cache crash with this project's relocated build directory. The mock (`MockModelInferenceService`) is retained only as an explicit non-Android fallback (web/desktop dev builds), not the default.

**Goal:** A `ModelInferenceService` in the Flutter app that can load Gemma 4 (E2B or E4B) via LiteRT-LM on Android and produce streamed text completions from a prompt, with download management, RAM-tier selection, and graceful failure handling.

**Depends on:** Phase 01 (app shell, settings provider). Phase 07's mockups for this phase's user-facing screens are done: AI DM Onboarding / first-run model download (`projects/6748340587166257171/screens/5703b39fd1524832a48d176043c671fa`), Settings & AI Configuration incl. E2B/E4B tier picker (`.../68d6594b824045e585c5c21004f9ef78`) — see `07-ui-design-stitch.md`'s Screen registry.
**Enables:** Phase 03 (AI DM engine consumes this service).

## Facts this phase is built on (verified 2026-08-29)

- Gemma 4 E2B/E4B are the on-device-targeted variants (4-bit quantized: E2B ≈1.5–2GB RAM, E4B ≈4–6GB).
- Google's current recommended on-device runtime is **LiteRT-LM**, not the older MediaPipe LLM Inference API (that API is maintenance-only as of 2026). Build against LiteRT-LM.
- LiteRT-LM ships as a native library with Android bindings; Flutter has no official plugin for it, so this phase builds a **platform channel** (`MethodChannel` + `EventChannel` for streaming tokens) wrapping a small Kotlin/Java module that calls LiteRT-LM directly.
- iOS: at time of writing, LiteRT-LM's iOS maturity lags Android. This phase's tasks are Android-only. iOS gets a decision point at the end of this file rather than a false promise of parity.

## Deliverables

1. Native Android module (`android/app/src/main/kotlin/.../llm/`) that loads a LiteRT-LM model file and exposes `loadModel`, `generate` (streaming), `unloadModel`, `getDeviceRamTier`.
2. Dart-side `ModelInferenceService` wrapping the platform channel with a clean async/stream API.
3. Model download manager: fetches the correct quantized `.task`/`.litertlm` model file from Google's hosted model repo (or a project-controlled mirror in Firebase Storage/Cloud Storage — decide based on Google's redistribution terms for the exact artifact), shows progress, verifies checksum, stores in app-private storage.
4. Device RAM-tier detection to pick E2B vs E4B automatically, with manual override in Settings.
5. Timeout/failure handling: if inference stalls or the device can't allocate memory, surface a typed error the UI can show, not a crash.
6. A debug screen (dev-only route) that sends a raw prompt and shows the streamed response — this is the integration test harness for Phase 03.

## Tasks

### 1. Get a running LiteRT-LM Android sample first
- Before writing any Flutter glue, build and run Google's LiteRT-LM Android sample/reference app standalone (outside Flutter) with a Gemma 4 E2B model file, on a physical device. This validates the model file, license access, and native library work at all, before adding Flutter's platform-channel complexity on top.
- Confirm: model loads, a test prompt produces a streamed response, memory usage is within the ~2GB budget for E2B.

### 2. Vendor the native module into the Flutter Android project
- Copy/adapt the working native inference code into `android/app/src/main/kotlin/.../llm/LlmEngine.kt`.
- Wrap it in a class with: `suspend fun loadModel(path: String, params: ModelParams): Boolean`, `fun generateStream(prompt: String, sessionId: String): Flow<String>`, `fun unload()`.
- Add the LiteRT-LM dependency to `android/app/build.gradle` per its published Maven coordinates.

### 3. Build the platform channel bridge
- `MethodChannel("dnd_ai/llm_control")` for `loadModel`/`unloadModel`/`getDeviceRamTier` (request/response calls).
- `EventChannel("dnd_ai/llm_stream")` for token streaming — each native token/chunk emitted as an event, terminated by a sentinel end-of-stream event or channel close.
- Handle channel errors (`PlatformException`) and map them to a Dart-side sealed error type (`ModelLoadError`, `ModelOomError`, `ModelTimeoutError`, `ModelUnknownError`).

### 4. Dart `ModelInferenceService`
```
class ModelInferenceService {
  Future<void> ensureModelReady(); // checks download, loads if needed
  Stream<String> generate(String prompt, {required String sessionId, int maxTokens = 512});
  Future<void> unload();
  RamTier get deviceTier; // E2B or E4B
}
```
- Backed by a Riverpod provider (`modelInferenceServiceProvider`) so Phase 03's DM engine can consume it without knowing about platform channels.
- Add a hard timeout (e.g. 30s to first token) that cancels the stream and emits `ModelTimeoutError` — an LLM that never responds must not hang the game.

### 5. Model download manager
- On first app launch (or first "Play Solo" tap), check for the model file in app-private storage (`getApplicationDocumentsDirectory()` equivalent).
- If absent: show a screen explaining the ~1.5–2GB download, require Wi-Fi or explicit "use mobile data" consent, download with progress (use `dio` or `http` with range support + resumability), verify a SHA-256 checksum against a known-good value, then move into place.
- Store the download source URL and checksum in a config file (`assets/model_manifest.json`) rather than hardcoding, so the model version can be bumped without a code change.
- **License/redistribution check (do this before shipping):** confirm whether the app can point directly at Google's hosted model artifact URL or must have the user download via Google's own flow (e.g. through Hugging Face / Kaggle / Google AI Edge model hub with the user accepting Gemma's license). Do not silently mirror and redistribute the model weights from project infrastructure without confirming this is allowed under the Gemma Terms of Use.

### 6. RAM-tier detection
- Native side: read `ActivityManager.MemoryInfo.totalMem` via the platform channel's `getDeviceRamTier` call.
- Rule: `totalMem >= 6GB` → offer E4B as default (still user-overridable down to E2B); `< 6GB` → E2B only, hide E4B option entirely (don't let a 4GB device pick a model that will OOM).

### 7. Debug harness screen
- Dev-only route `/debug/llm` (only compiled in debug builds via `kDebugMode` guard) with a text field, "Send" button, and a scrolling text view showing the streamed response plus tokens/sec and time-to-first-token, read from Performance Monitoring custom traces (Phase 08 wires the actual trace recording; this screen just displays local timing for now).

## iOS decision point (flag, don't resolve yet)

When Phase 09 (or whenever iOS work actually starts) begins: re-check LiteRT-LM iOS support maturity. If it's not production-ready, the fallback is a llama.cpp-based runtime (via a Flutter FFI binding, e.g. `llama_cpp_dart`) loading a GGUF-quantized Gemma 4 build. This is a real fallback, not a placeholder — llama.cpp has supported Gemma GGUF quantization since Gemma 1, so it's a proven path if needed. Do not silently ship Android-only; make the call explicitly when iOS work starts.

## Acceptance criteria

- [ ] Standalone LiteRT-LM sample app runs Gemma 4 E2B on a physical Android device and produces a response.
- [ ] `ModelInferenceService.generate()` streams tokens into the debug harness screen from within the Flutter app.
- [ ] A device with <6GB RAM is automatically restricted to E2B; a device with ≥6GB RAM can select E4B.
- [ ] Killing the model mid-generation (airplane mode toggle, force-stop) does not crash the app — it surfaces a typed error.
- [ ] Model download resumes correctly if interrupted partway through.

## Key files

- `android/app/src/main/kotlin/.../llm/LlmEngine.kt`
- `lib/services/model_inference_service.dart`
- `lib/services/model_download_manager.dart`
- `lib/data/model_manifest.dart` (+ `assets/model_manifest.json`)
- `lib/debug/llm_debug_screen.dart`
