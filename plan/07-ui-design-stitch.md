# Phase 07 — UI/UX Design System (Google Stitch)

> **Status: design system + all 12 screens generated (2026-08-29).** See the Screen Registry below for IDs/links. What remains is the Flutter translation work (Tasks 4–5) — that has not been started; do not assume the app UI matches these mockups yet.

**Goal:** A coherent, "beautiful" visual identity for the whole app — produced in Google Stitch — translated into a Flutter theme + asset set that Phases 04/05's placeholder UI gets upgraded into.

**Depends on:** Phase 00's phase list (needs to know what screens exist), can run in parallel with Phases 02–06 since it only produces design artifacts + a Flutter theme, not game logic.
**Enables:** Final polish of Phases 04 (avatar/character UI), 05 (tile art), and general app chrome.

**Tooling note:** This project has Stitch MCP tools available directly (`mcp__stitch__*`): `create_project`, `create_design_system`, `generate_screen_from_text`, `edit_screens`, `generate_variants`, `apply_design_system`, `list_screens`, `get_screen`. Stitch produces visual designs/screens, not Flutter code — treat its output as the authoritative visual reference (colors, typography, layout, iconography) that gets hand-translated into Flutter `ThemeData` and widget layouts, not as a code generator.

## Stitch project reference

- **Project:** "DnD AI — Mobile" — `projects/6748340587166257171`
- **Design system:** "Arcane Dark" — `assets/6622902524875945862` (dark mode, Playfair Display headlines, Manrope body/label, EXPRESSIVE violet/gold/red palette seeded from `#8B5CF6`, `ROUND_TWELVE` corners). Pass this asset ID to `generate_screen_from_text`'s `designSystem` param for any future screen so it stays consistent with the set below.
- To pull any screen's live data again later (mockup image, HTML, or the exact prompt used): call `mcp__stitch__get_screen` with the screen's resource `name` from the table below. Do this rather than relying on the `screenshot.downloadUrl` / `htmlCode.downloadUrl` values already recorded — those are signed URLs that can expire; `get_screen` re-issues fresh ones.
- **Known tool quirk:** `generate_screen_from_text` timed out on the client side for roughly half of the calls made during this session even though the screen was generated successfully server-side (confirmed via the project's `updateTime` advancing and, ultimately, the screen coming back on a later identical retry). `list_screens` also returned an empty result throughout this session despite screens existing — don't trust it as a completeness check; use `get_project` (for a thumbnail sanity check) or `get_screen` by ID instead. If regenerating any screen below, retry the identical prompt 2–5× on timeout rather than assuming failure, and be aware retries may have created extra duplicate screen instances in the project that aren't reflected in this registry — spot-check the project in the Stitch UI before treating it as clean.

## Screen registry (all generated, 2026-08-29)

| # | Screen | Maps to plan section | Stitch screen resource name |
|---|---|---|---|
| 1 | Campaign Hub (Home) | Phase 00 nav shell `/home` | `projects/6748340587166257171/screens/cd503fbea3084ba0994fef469174ca45` |
| 2 | Choose Your Race (creation step 1/5) | Phase 04 Task 3 | `projects/6748340587166257171/screens/f3eaedac145d48878ab9b165358bdbfb` |
| 3 | Choose Your Class (creation step 2/5) | Phase 04 Task 3 | `projects/6748340587166257171/screens/364a742e8ff44ac6a1b11ab4196b7f52` |
| 4 | Choose Your Background (creation step 3/5) | Phase 04 Task 3 | `projects/6748340587166257171/screens/f1310439a391484597f1cf4720037899` |
| 5 | Ability Score Allocation (creation step 4/5) | Phase 04 Task 4 (point-buy allocator) | `projects/6748340587166257171/screens/e7cf46e6a5bf44d9b34522f233e62252` |
| 6 | Character Appearance / avatar builder (creation step 5/5) | Phase 04 Task 5 (layered avatar builder) — **highest-priority screen** | `projects/6748340587166257171/screens/b431c2e978b04d1ea8983978af1ca186` |
| 7 | Character Summary & Review (creation final step) | Phase 04 Task 6 | `projects/6748340587166257171/screens/1a66cb7d94824f39bcb128d774f97f91` |
| 8 | Main Gameplay Screen (map + AI narration panel) | Phase 05 Task 4, Phase 03 turn loop UI — **highest-priority screen** | `projects/6748340587166257171/screens/0c7b23c25db94929bb4df57fd9d56dc7` |
| 9 | Multiplayer Lobby | Phase 06 Task 3 (session lifecycle UI) | `projects/6748340587166257171/screens/d942a70e24f44aa3b6c3b79423b25b34` |
| 10 | Join a Campaign | Phase 06 Task 3 (join flow UI) | `projects/6748340587166257171/screens/140d51696d774c14a226b23ba507483e` |
| 11 | Settings & AI Configuration | Phase 02 Task 6 (RAM tier picker), Phase 08 Task 6 (diagnostics button) | `projects/6748340587166257171/screens/68d6594b824045e585c5c21004f9ef78` |
| 12 | AI DM Onboarding (first-run model download) | Phase 02 Task 5 (model download manager UI), Phase 09 Task 4 (onboarding polish) | `projects/6748340587166257171/screens/5703b39fd1524832a48d176043c671fa` |

## Deliverables

1. A Stitch project for the game with a defined **design system**: color palette (dark-fantasy-friendly, since D&D UIs read better dark-first), typography (a display face for headers/fantasy flavor + a highly legible body face for long narration text), spacing scale, corner radii, icon style.
2. ~~Full screen set generated/designed in Stitch: Home, Character Creation (all 5 steps + review), Play/Map screen, Multiplayer Lobby/Join, Settings, Model Download screen.~~ **Done — see Screen registry above (12/12 screens).**
3. A translated Flutter `ThemeData` (`lib/app/theme.dart`) matching the Stitch design system exactly (colors, text styles, component shapes).
4. Exported static art assets (icons, backgrounds, decorative frame elements) placed into `assets/` per the manifests defined in Phases 04/05.

## Tasks

### 1. ~~Establish the design system in Stitch~~ — Done
- Project `projects/6748340587166257171`, design system "Arcane Dark" `assets/6622902524875945862`. Locked tokens (use these verbatim in Task 4, don't re-derive by eyeballing screenshots):
  - **Background:** near-black desaturated indigo, `#0F0D17` range.
  - **Primary (interactive, magic/AI-state):** `#8B5CF6` (violet).
  - **Secondary (currency/XP/treasure borders):** `#C9A227` (aged gold).
  - **Tertiary/danger (HP bars, damage):** `#B0263A` (blood red).
  - **Headline font:** Playfair Display. **Body/label font:** Manrope. Never use Playfair for paragraph-length narration text.
  - **Corner radius:** 12dp (`ROUND_TWELVE`) throughout.
  - Full rationale/usage rules are in the design system's `designMd` — fetch via `get_project` (`designTheme.designMd` field) if the reasoning behind a token is needed later.

### 2. ~~Generate the core screens~~ — Done, 12/12
- All screens generated; see the Screen registry table above for resource names. If a screen needs a layout variant explored later (the avatar builder and map screen are the most likely candidates), use `generate_variants` against the existing screen ID rather than starting a fresh `generate_screen_from_text` call, so it inherits the exact same design system application.

### 3. Review and refine — **not yet done, do this before Task 4**
- Fetch each screen via `get_screen` (not `list_screens` — it returned empty all session, see Known tool quirk above) and eyeball the full set together for consistency (spacing, button styles, header treatment) before committing colors/type to Flutter code.
- Use `edit_screens` for targeted fixes. Two screens flagged during generation as worth a second look: the **Ability Score Allocation** screen used a circular "points remaining" badge that may or may not match the flatter chip style used elsewhere (compare against Multiplayer Lobby's chips); the **Character Appearance** screen's carousel thumbnail selected-state (gold vs. violet border) should be made consistent with the Race/Class/Background card selected-state (which came out violet-bordered) — pick one and apply it everywhere via `edit_screens`, don't let it stay split.

### 4. Import into the Flutter/Android app (the actual "get this into the codebase" step)
There is no Stitch→Flutter code export in the available tooling — `htmlCode` on each screen is an HTML/CSS mockup for visual reference only, not something to compile into the app. The practical, lowest-friction import path:
- **Pull static references into the repo once, so the team isn't dependent on live Stitch access or expiring signed URLs:** for each row in the Screen registry, call `get_screen`, save the `screenshot` image under `docs/design/mockups/<screen-name>.png`, and save the `htmlCode` under `docs/design/mockups/<screen-name>.html` (useful for reading exact pixel spacing/layout via browser devtools even though it won't be compiled). Do this once, right after Task 3's edits land, so the reference set matches the final approved designs, not an intermediate draft.
- **Hand-translate tokens into `lib/app/theme.dart`** using the locked values from Task 1 (not re-extracted per-screen — that's how you get drift between screens). Concretely: `ColorScheme.dark(primary: Color(0xFF8B5CF6), secondary: Color(0xFFC9A227), error: Color(0xFFB0263A), surface: Color(0xFF0F0D17), ...)`; `TextTheme` with `Playfair Display` (via `google_fonts` package: `GoogleFonts.playfairDisplay(...)`) for `displayLarge`/`headlineLarge`/`titleLarge`, `Manrope` (`GoogleFonts.manrope(...)`) for everything else; `CardTheme`/`ElevatedButtonThemeData`/`InputDecorationTheme` all with 12px `BorderRadius`.
- **Rebuild Phase 04/05's placeholder widgets layout-by-layout against the saved mockup images** (not against live Stitch — faster iteration, no network dependency, and the mockups won't shift under you mid-implementation). This is a visual pass on existing widget trees, not a rewrite of their logic.
- Google Fonts note for Android offline play: `google_fonts` package downloads font files over the network on first use by default. Since this app must work fully offline (Phase 00 constraint), either bundle Playfair Display and Manrope as local font assets in `pubspec.yaml`/`assets/fonts/` (recommended — guarantees the font renders correctly with zero network on first launch) or explicitly call `GoogleFonts.config.allowRuntimeFetching = false` after pre-bundling the font files via the package's asset bundling option. Don't ship with default runtime-fetching behavior untested against airplane mode.

### 5. Produce real game art assets (separate from the Stitch screens)
Stitch's screens are whole-screen UI mockups — they are **not** a source of the layered, individually-croppable sprite assets Phase 04's avatar builder (`assets/avatar/{layer}/{option}.png`) and Phase 05's tile renderer (`assets/tiles/`) need. Don't try to crop these out of the mockup screenshots as a shortcut; the character portraits and map tiles shown in the mockups are single illustrative compositions, not layer-separated assets. Treat asset production as its own task:
- Use the mockups' art direction (character portrait style seen in screens #6/#7, the stone/torch tile style seen in screen #8) as the brief for whoever/whatever generates the actual layered PNGs.
- Drop the finished layered art into `assets/avatar/manifest.json` and `assets/tiles/manifest.json` per Phase 04/05's manifest-driven structure — no code changes needed there, only asset + manifest updates, as those phases were built to allow exactly this.

## Acceptance criteria

- [x] A Stitch design system exists and every generated screen references it (no one-off screens with inconsistent colors/type).
- [x] All 12 screens in the deliverables list are generated.
- [ ] Full-set consistency review done via `edit_screens` (Task 3) — flagged inconsistencies (selected-state border color, points-remaining badge style) resolved.
- [ ] Approved mockups saved to `docs/design/mockups/` so the team isn't dependent on live Stitch/expiring URLs.
- [ ] `lib/app/theme.dart` implemented with the locked token values above; offline font rendering verified in airplane mode.
- [ ] `lib/app/theme.dart` produces a running app whose look matches the saved mockups closely enough that a side-by-side comparison holds up.
- [ ] Real layered art assets (avatar layers, tiles) produced and replace Phase 04/05 placeholders via manifest updates only.

## Key files

- `docs/design/mockups/*.png`, `*.html` (pulled reference copies of each Stitch screen)
- `lib/app/theme.dart`
- `assets/avatar/*.png`, `assets/tiles/*.png` (final layered art, manifest-referenced — not sourced from Stitch screenshots directly)
- `assets/fonts/PlayfairDisplay-*.ttf`, `assets/fonts/Manrope-*.ttf` (bundled for offline rendering)
