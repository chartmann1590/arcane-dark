# Phase 09 — Testing, Polish & Store Launch

**Goal:** Ship a stable v1.0 to the Google Play Store (Android lead platform per Phase 00), with a real QA pass on low-end hardware, a finalized store listing, and a decision made (not deferred again) on iOS timing.

**Depends on:** all prior phases functionally complete.

## Tasks

### 1. Low-end device QA pass
- Test the full solo flow (character creation → campaign seed → 30+ minute play session) on:
  - A 4GB RAM reference Android device (E2B tier) — this is the actual floor the app must support, not an emulator with unrealistic memory headroom.
  - A 6-8GB flagship-class device (E4B tier).
- Watch for: thermal throttling during long generation streaks, OOM kills during model load while other apps are backgrounded (not killed), battery drain rate during a play session (log via Performance Monitoring's battery metrics if available, or manual measurement).

### 2. Multiplayer QA pass
- Real multi-device test (not just emulators) with at least 3 physical devices over real Wi-Fi/cellular, including one deliberate host-disconnect-and-reconnect test and one deliberate "join with wrong code" / "join a full-6-player session" edge case test.

### 3. Content/safety pass on AI output
- Run a batch of varied play sessions (different tones: horror, high-magic, grimdark) and review transcripts for: the Gemma Prohibited Use Policy compliance, no persistent narrative loops (the model repeating itself), no broken tool-call syntax leaking into visible narration text.
- Add a lightweight client-side output filter as a safety net (not a replacement for good prompting) that strips any stray unparsed `<<ACTION:` fragments from displayed text if the parser in Phase 03 ever fails to fully consume one.

### 4. Onboarding polish
- First-run flow: explain the model download requirement clearly (size, why it's needed, Wi-Fi recommendation) before starting the download — this was flagged as a hard requirement in Phase 02, verify it reads well and doesn't feel like a bait-and-switch after install.
- Empty states: no characters yet, no campaigns yet, no multiplayer sessions yet — each should have a clear call-to-action, not a blank screen.

### 5. Store listing
- Play Store listing: screenshots taken from the final Phase 07 UI (not placeholder art), a short capture/GIF of the avatar builder and the map, and a description that's upfront about the on-device AI requirement (device storage/RAM needed) so reviews don't get tanked by users on unsupported low-end devices installing and hitting a wall.
- Content rating questionnaire: answer accurately given AI-generated narrative content can include fantasy violence and unpredictable (though policy-constrained) text — don't under-declare.
- Privacy policy: must disclose Firebase Auth/Firestore usage for multiplayer and explicitly state solo-mode content never leaves the device (this is a real differentiator, state it clearly).

### 6. iOS decision (resolve the Phase 02 flag)
- At this point, re-verify LiteRT-LM iOS maturity. Decide: (a) ship iOS with LiteRT-LM if it's production-ready, (b) ship iOS with the llama.cpp/GGUF fallback runtime, or (c) explicitly delay iOS to a v1.1 and say so in the store presence (Android-only v1.0). Record the decision and reasoning — do not let this stay silently unresolved past launch.

### 7. Release build hardening
- Enable Flutter's release-mode obfuscation (`--obfuscate --split-debug-info`) and upload the resulting symbol files to Crashlytics so release crashes are still readable.
- Confirm ProGuard/R8 rules don't strip anything the LiteRT-LM native bridge needs (test a release APK, not just debug, against the full solo flow before submitting).
- Final check of Firestore security rules and Spark quota headroom under a simulated realistic day-one load estimate.

## Acceptance criteria

- [ ] Full solo and multiplayer flows pass on real low-end and flagship hardware.
- [ ] No unhandled crashes in a 2-hour combined soak test across both modes.
- [ ] Store listing, screenshots, privacy policy, and content rating are complete and accurate.
- [ ] iOS timing decision is made and documented, not left ambiguous.
- [ ] Release (not debug) build tested end-to-end, with readable Crashlytics symbolication confirmed via one forced test crash on the release build.

## Key files

- `docs/release-checklist.md` (create this as the living checklist derived from the acceptance criteria above)
- `android/app/build.gradle` (release signing, ProGuard/R8 rules, obfuscation flags)
- Store listing assets under `store/` (screenshots, description, privacy policy text)
