# Solo/Co-op On-Device AI D&D — Master Plan

> REQUIRED READING ORDER: this file, then `01`–`09` in numeric order. Each phase file is self-contained: goal, deliverables, architecture decisions, task list, acceptance criteria. Execute phases in order — later phases depend on earlier ones (e.g. multiplayer depends on the data schema from Phase 01; the AI DM depends on the model runtime from Phase 02).

## What we're building

A mobile app (Android first, iOS second) that runs a Dungeons & Dragons–style RPG:
- **Solo mode**: a fully on-device AI Dungeon Master (Gemma 4, on-device via LiteRT-LM) generates storylines, NPC dialogue, and narrates play. No network, no server cost, works offline.
- **Multiplayer mode**: 2–6 friends join a session over the internet. One device (the host) or a lightweight Cloud Function-free Firestore-backed session acts as the shared game state; the on-device AI still narrates for the host, or each device runs its own model and the "DM" role is elected/hosted.
- **Character creation**: graphical, animated, stat-buy/point-pool + race/class selection, live-rendered character portrait/avatar built from layered art (not photoreal, stylized 2D — see Phase 04 for why).
- **Procedural maps**: tile-based dungeon/overworld generation, seeded, AI-assisted room/encounter placement.
- **Storylines**: AI-generated quests/campaigns constrained by a structured "campaign schema" so the LLM can't derail the game into incoherence.
- **Backend**: Firebase Spark (free) plan — Auth, Firestore, Storage, Crashlytics, Performance Monitoring. No Cloud Functions/Blaze spend required for MVP.

## Fact-check on the premise (verified 2026-08-29 via web search)

The user's premise is correct and the plan is built on it:
- **Gemma 4 shipped April 2, 2026** (Google), Apache 2.0, built on Gemini 3 research. Sources: [Android Developers Blog](https://android-developers.googleblog.com/2026/04/AI-Core-Developer-Preview.html), [InfoQ](https://www.infoq.com/news/2026/04/gemma-4-android-ai-inference/), [Hugging Face google/gemma-4-E4B](https://huggingface.co/google/gemma-4-E4B).
- On-device variants **Gemma 4 E2B and E4B** are purpose-built for phones/edge hardware. 4-bit quantized: E2B ≈1.5–2GB RAM footprint, E4B ≈4–6GB. Treat E2B as the baseline target (broad device compatibility), E4B as an optional "high quality" tier gated on a device RAM check.
- Gemma 4 is the base for the next **Gemini Nano** generation — meaning some devices may eventually get a system-level AICore path, but **do not depend on AICore** for MVP; ship via the app-bundled runtime path below so the app works on any device today, including non-Pixel Android and iOS.
- **Runtime**: Google's **MediaPipe LLM Inference API is now in maintenance-only mode**. The supported forward path is **LiteRT-LM** ([announcement](https://developers.googleblog.com/blazing-fast-on-device-genai-with-litert-lm/)). Build against LiteRT-LM, not the old MediaPipe GenAI tasks API.
- iOS on-device path: LiteRT-LM's iOS support is newer/thinner than Android's. Plan assumes **Android is the lead platform**; iOS ships in a later phase and may fall back to a llama.cpp-based GGUF runtime for Gemma if LiteRT-LM iOS isn't production-ready when we get there (decision point flagged in Phase 02).

## Architecture decisions (locked for planning purposes)

| Decision | Choice | Why |
|---|---|---|
| Client framework | **Flutter** (Dart) | One codebase for Android+iOS, strong Firebase plugin support (FlutterFire), good for both UI-heavy screens (character creation) and a 2D game canvas (via the Flame engine package) |
| 2D game/map rendering | **Flame** (Flutter game engine package) embedded inside Flutter widget tree | Avoids pulling in Unity just for tile maps; keeps one language/toolchain; Flame has tilemap, camera, and sprite-animation support |
| On-device LLM runtime | **LiteRT-LM** via platform channel (Android first) | Current Google-recommended path for Gemma on-device (see fact-check above) |
| Model | **Gemma 4 E2B** (4-bit) default, **E4B** opt-in on high-RAM devices | Fits phone RAM budgets; E4B for quality on flagship devices |
| Backend | **Firebase Spark (free) plan**: Auth, Firestore, Storage, Crashlytics, Performance Monitoring | Zero cost, sufficient for turn-based/session-based multiplayer at small scale; no Cloud Functions needed for MVP (client-authoritative host model, see Phase 06) |
| Design tooling | **Google Stitch** (via MCP) for screen mockups/design system; export to Flutter widget structure by hand (Stitch doesn't emit Flutter code, so it's a visual/UX reference, not a codegen source) | Requested by user; fastest way to get a coherent visual design system before writing widget code |
| State management | **Riverpod** | Standard, testable, works well with Flutter+Firebase streams |
| Persistence (local) | **Drift (SQLite)** for character sheets, campaign state, offline solo-play saves | Solo mode must work with zero network; Firestore is multiplayer-only |

## Phase list

1. **[Phase 01 — Foundation & Project Setup](01-foundation-and-setup.md)** — repo, Flutter project, Firebase project via CLI/MCP, CI, app shell, navigation.
2. **[Phase 02 — On-Device AI Runtime (Gemma 4 / LiteRT-LM)](02-on-device-ai-runtime.md)** — model packaging, platform channel, inference service, prompt harness, safety/latency handling.
3. **[Phase 03 — AI Dungeon Master Engine](03-ai-dungeon-master-engine.md)** — structured campaign/story schema, narration loop, function-calling for dice/combat/inventory, context window management.
4. **[Phase 04 — Character Creation System](04-character-creation-system.md)** — graphical stat-buy, race/class/background picker, layered avatar renderer, save to local+cloud.
5. **[Phase 05 — Procedural Map Generation](05-procedural-map-generation.md)** — tile-based dungeon/overworld generator, seeded RNG, AI-assisted encounter/loot placement, Flame rendering.
6. **[Phase 06 — Multiplayer & Firebase Backend](06-multiplayer-firebase-backend.md)** — Auth, Firestore session schema, host-authoritative sync, Spark-plan quota management.
7. **[Phase 07 — UI/UX Design System (Google Stitch)](07-ui-design-stitch.md)** — design system + full screen set produced in Stitch, translated to Flutter theme/widgets. **Status: design system + all 12 mockup screens generated (project `projects/6748340587166257171`, design system `assets/6622902524875945862`); Flutter translation not yet started — see that file's Screen registry.**
8. **[Phase 08 — Observability (Crashlytics & Performance Monitoring)](08-observability-crashlytics-performance.md)** — crash reporting, custom traces for model-inference latency, non-fatal error logging.
9. **[Phase 09 — Testing, Polish & Store Launch](09-testing-polish-launch.md)** — QA pass, performance budget on low-RAM devices, store listing, phased rollout.

## Cross-cutting global constraints

(Every phase file's tasks implicitly inherit these.)

- **Offline-first**: solo mode must be 100% playable with airplane mode on, after the model is downloaded once.
- **RAM budget**: app + Flutter engine + Gemma 4 E2B (4-bit) must run within a 4GB-RAM Android device's app memory ceiling. Test on a low-end reference device, not just flagship emulators.
- **No paid backend spend for MVP**: everything must fit Firebase Spark plan limits (1GiB Firestore storage, 10GiB/month egress, 50K reads / 20K writes / 20K deletes per day). Multiplayer design must degrade gracefully if quota is hit.
- **Model download size**: Gemma 4 E2B 4-bit is roughly 1.5–2GB — do not bundle it in the APK/IPA; download-on-first-run over Wi-Fi with explicit user consent, store in app-private storage.
- **Privacy**: all AI narration for solo play happens on-device; no campaign/character text leaves the device unless the user is in multiplayer mode (and then only session-relevant state goes to Firestore, never raw model prompts/completions).
- **Attribution**: Gemma is Apache 2.0 but Google's Gemma usage policy requires following the Gemma Prohibited Use Policy — link it from Settings/About.

## What's explicitly out of scope for MVP (call out, don't silently drop)

- Voice input/output.
- 3D rendering (2D tile-based only).
- Real-money purchases / IAP.
- Cross-campaign persistent world shared by all players (each session/campaign is its own isolated save).
