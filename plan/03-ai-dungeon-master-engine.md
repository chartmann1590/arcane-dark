# Phase 03 — AI Dungeon Master Engine

**Goal:** Turn raw LLM text generation (Phase 02) into a coherent, game-aware Dungeon Master: it narrates, remembers campaign state, calls game functions (dice rolls, combat resolution, inventory changes) instead of hallucinating them in prose, and stays within a bounded context window across a long play session.

**Depends on:** Phase 02 (`ModelInferenceService`).
**Enables:** Phase 04 (character data feeds the DM's context), Phase 05 (maps feed the DM's spatial awareness), Phase 06 (multiplayer sessions need one authoritative DM state machine).

## Why this phase exists (the core design problem)

A raw LLM asked to "be a dungeon master" will drift, contradict itself, invent rules, and can't reliably roll dice or track HP. This phase's job is to constrain the model with **structured state + function-calling-style tool use + a small context window budget**, so a small on-device model (E2B, ~2-4B effective params) stays coherent for hours of play instead of minutes.

## Deliverables

1. `CampaignState` data model: current scene, active NPCs, party status, quest log, world flags — serializable, stored via `drift` (local) and mirrored to Firestore for multiplayer sessions (Phase 06).
2. A **DM turn loop**: player input → prompt assembly (system prompt + compressed history + current state) → model generates either narration or a structured "action call" → action executed against `CampaignState` → narration shown to player.
3. A small fixed set of DM tool-calls the model can invoke via a constrained output format (not free-form JSON hallucination): `roll_dice(sides, count, modifier)`, `update_hp(target, delta)`, `add_item(target, item)`, `move_party(destination)`, `trigger_encounter(encounter_id)`, `advance_quest(quest_id, stage)`.
4. Context window manager: summarizes older turns into a running "campaign summary" string when the token budget is close to the model's context limit, so sessions don't degrade after N turns.
5. A starting **campaign seed schema** — a lightweight structured template (setting, tone, starting hook, 3–5 planned story beats) the model fills in at campaign creation, so the story has a shape instead of being fully improvised turn-by-turn.

## Tasks

### 1. Define `CampaignState`
```dart
class CampaignState {
  String campaignId;
  String currentSceneDescription;
  List<NpcRef> activeNpcs;
  List<PartyMemberStatus> party; // hp, conditions, inventory refs
  List<QuestEntry> questLog; // id, title, stage, status
  Map<String, dynamic> worldFlags; // e.g. {"burnedDownTavern": true}
  String runningSummary; // compressed history, see task 5
  List<TurnLogEntry> recentTurns; // last N raw turns, uncompressed
}
```
- Persist via `drift` table `campaign_states`; one row per campaign.

### 2. Design the system prompt + output contract
- System prompt fixes: DM persona, tone rules, the exact tool-call syntax the model must use (e.g. a reserved delimiter block like `<<ACTION: roll_dice sides=20 count=1 modifier=3>>`), and a hard rule: "narrate in-character, never break the fourth wall, never invent a tool call not in this list."
- Because E2B is a small model, keep the tool-call syntax extremely simple and low-ambiguity (fixed keyword + key=value pairs), not open JSON — small models are much more reliable at rigid templated output than at valid JSON.

### 3. Build the turn loop
```dart
class DmTurnEngine {
  Future<DmTurnResult> takeTurn({required String playerInput, required CampaignState state});
}
```
- Assemble prompt: system prompt + `state.runningSummary` + last K `recentTurns` + `playerInput`.
- Stream the model's response; parse it for `<<ACTION: ...>>` blocks as they arrive.
- On detecting an action block: pause narration, execute the corresponding deterministic Dart function (dice rolls use a real seeded RNG — **never trust the model's own claimed dice result**, only its declared intent to roll), splice the real result back into context, and let the model continue narrating with the true outcome.
- Append the turn to `recentTurns`, update `CampaignState`, persist.

### 4. Implement the tool functions (deterministic, not model-generated)
- `roll_dice(sides, count, modifier)` → real RNG roll, returns total + individual dice for narration flavor.
- `update_hp`, `add_item`, `move_party`, `trigger_encounter`, `advance_quest` → pure state mutations against `CampaignState`, each unit-testable without touching the model at all.
- Write unit tests for each tool function against a fixture `CampaignState` — these must be deterministic and testable independent of the LLM.

### 5. Context window management
- Track approximate token count of the assembled prompt (character count / 4 heuristic is fine for a budget check, doesn't need a real tokenizer).
- When `recentTurns` + summary approach ~70% of the model's context limit, trigger a **summarization pass**: send the oldest half of `recentTurns` to the model with a "compress this into 2-3 sentences of campaign history" prompt, replace them in `runningSummary`, drop them from `recentTurns`.
- This keeps every DM turn's prompt roughly bounded regardless of session length.

### 6. Campaign seed / story shape
- At campaign creation (triggered from Phase 04's character creation flow), run one "seed" generation: prompt the model with the party's characters + a chosen setting/tone (user picks from a short list: e.g. "classic fantasy," "grimdark," "high-magic wonder," "horror") and ask it to output a structured seed: opening hook, 3–5 planned beats, a starting location, one recurring villain/faction.
- Store this as `CampaignSeed` (separate from moment-to-moment `CampaignState`) and reference it in the system prompt so improvised play still tracks toward planned beats instead of wandering forever.

### 7. Failure handling
- If the model's output contains no parseable action block when one was expected (e.g. player said "I attack"), fall back to a deterministic prompt retry once ("Your last response didn't include a valid action — respond again using the `<<ACTION: ...>>` format"), then if it fails twice, resolve the action with a sane default (e.g. a straight ability-check roll) rather than stalling the game.

## Acceptance criteria

- [ ] A full solo playthrough of a short (~15 minute) encounter completes with coherent narration, correct HP tracking, and no invented dice results (all rolls traceable to the real RNG).
- [ ] Sessions of 100+ turns don't blow the context budget — summarization is observed firing.
- [ ] All six tool functions have passing unit tests independent of the LLM.
- [ ] Model failing to produce a valid action block is handled without the game stalling or crashing.

## Key files

- `lib/domain/campaign_state.dart`
- `lib/domain/dm_turn_engine.dart`
- `lib/domain/dm_tools.dart` (the six deterministic tool functions)
- `lib/domain/campaign_seed.dart`
- `lib/data/local/campaign_dao.dart` (drift)
