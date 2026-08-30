# Phase 04 — Character Creation System

**Goal:** The flagship "awesome graphical" character creation flow — race/class/background selection, point-buy stats, and a live layered-avatar builder — that produces a `Character` record consumed by Phase 03's DM engine and Phase 05's map renderer.

**Depends on:** Phase 01 (app shell), Phase 07's design system informs the final visuals (this phase can build with placeholder art first and swap assets once Phase 07 delivers them — don't block on design). Phase 07's mockups for this phase's five screens are already done: Race (`.../screens/f3eaedac145d48878ab9b165358bdbfb`), Class (`.../364a742e8ff44ac6a1b11ab4196b7f52`), Background (`.../f1310439a391484597f1cf4720037899`), Abilities (`.../e7cf46e6a5bf44d9b34522f233e62252`), Appearance (`.../b431c2e978b04d1ea8983978af1ca186`), plus a Review/Summary screen (`.../1a66cb7d94824f39bcb128d774f97f91`) — see `07-ui-design-stitch.md`'s Screen registry for the full resource names.
**Enables:** Phase 03 (campaign seed needs party data), Phase 06 (character records sync to Firestore for multiplayer).

## Deliverables

1. `Character` data model covering: name, race, class, background, ability scores, skills, HP/AC derived stats, inventory, avatar layer selections.
2. A multi-step creation wizard (5 steps: Race → Class → Background → Abilities → Appearance) using `go_router`'s nested routing or a `PageView`, with back/forward and a progress indicator.
3. Point-buy ability score allocator (standard 27-point buy, D&D 5e-style cost curve) with live-updating derived stats (modifiers, HP, AC preview).
4. **Layered avatar builder**: a stack of PNG/SVG layers (body base, hair, face, armor/clothing, accessories) that recompose live as the user picks options — this is the "graphical and cool" centerpiece.
5. Persist finished characters to `drift` (local) and Firestore (`users/{uid}/characters/{characterId}`) once Phase 06's auth exists (guard this with a feature flag until Phase 06 lands — local-only save is the Phase 04 baseline).

## Tasks

### 1. Define the `Character` model
```dart
class Character {
  String id;
  String name;
  Race race; // enum: human, elf, dwarf, halfling, orc, tiefling, ...
  CharClass charClass; // enum: fighter, wizard, rogue, cleric, ranger, bard, ...
  Background background; // enum: soldier, sage, criminal, folk hero, ...
  AbilityScores abilities; // str, dex, con, int, wis, cha
  int hp;
  int armorClass;
  List<String> inventory;
  AvatarConfig avatar; // layer selections, see task 4
}
```
- `AbilityScores` derives modifiers via the standard `(score - 10) ~/ 2` formula; derived HP = class hit die + CON modifier at level 1; AC = 10 + DEX modifier (+ armor bonus once inventory affects it).

### 2. Build the step wizard shell
- `CharacterCreationFlow` widget owning a `PageController` (or nested `go_router` routes `/character/create/race`, `.../class`, etc.) and a `CharacterDraftNotifier` (Riverpod `StateNotifier<Character>`) holding in-progress selections across steps.
- Progress bar at top (5 segments), Back/Next buttons, Next disabled until the current step has a valid selection.

### 3. Race/Class/Background selection screens
- Grid or carousel of selectable cards, each showing name, a short flavor description, and (once Phase 07 assets exist) an icon/portrait thumbnail.
- Selecting a card updates `CharacterDraftNotifier` and shows an expandable detail panel (racial traits, class features, background perk) below the grid.

### 4. Point-buy ability allocator
- Standard 5e 27-point buy: scores start at 8, cost table `{8:0, 9:1, 10:2, 11:3, 12:4, 13:5, 14:7, 15:9}`, six scores, 27 points total, no score above 15 pre-racial-bonus.
- UI: six steppers (+/- buttons) with a running "points remaining" counter that goes red and disables further increases at 0.
- Apply racial ability bonuses (from the race picked in step 1) as a separate, clearly-labeled addition after base allocation, not blended into the buy pool.
- Live sidebar showing derived HP, AC, and modifiers updating as scores change.

### 5. Layered avatar builder (the visual centerpiece)
- Asset structure: `assets/avatar/{layer}/{option}.png`, layers in fixed z-order: `body`, `face`, `hair`, `outfit`, `accessory`. Start with a placeholder art set (simple flat-color silhouettes) so the mechanism can be built and tested before Phase 07's final art lands — swapping in final PNGs later requires zero code change if the manifest-driven approach below is followed.
- Build an `AvatarLayerManifest` (`assets/avatar/manifest.json`) listing available options per layer, keyed by race/class where relevant (e.g. armor options differ by class) so the builder doesn't hardcode option lists in Dart.
- `AvatarBuilderWidget`: a `Stack` of `Image.asset` layers, each swappable via a horizontal option carousel below the preview; changing a carousel selection swaps only that layer's image, giving instant visual feedback.
- Support a "randomize" button that picks a valid random combination — useful for quick starts and demoing the game.

### 6. Review & save screen
- Final step: full character sheet summary + avatar preview, "Create Character" button.
- Save to `drift` immediately (works offline). If Firebase Auth is available (post-Phase 06), also write to `users/{uid}/characters/{id}` in Firestore; if not yet authenticated, queue the write (a simple local "pending sync" flag) rather than blocking character creation on having a network account — this app must work for a solo, offline, no-account player.

### 7. Feed into the DM engine
- On character creation completion, if this is the party for a new campaign, hand the finished `Character` list to Phase 03's `CampaignSeed` generation step.

## Acceptance criteria

- [ ] A user can complete all 5 steps and land on a saved character with correct derived HP/AC/modifiers.
- [ ] Point-buy allocator enforces the 27-point cap and the 8–15 pre-racial range; UI makes remaining points and invalid states obvious.
- [ ] Avatar builder updates the preview instantly (no visible lag) when any layer option changes.
- [ ] A character created with no network connection and no Firebase account still saves successfully and is playable in solo mode.
- [ ] Swapping placeholder avatar art for final Phase 07 art requires editing only the manifest/assets, not Dart code.

## Key files

- `lib/domain/character.dart`, `lib/domain/ability_scores.dart`
- `lib/features/character_creation/character_creation_flow.dart`
- `lib/features/character_creation/steps/` (race, class, background, abilities, appearance screens)
- `lib/features/character_creation/avatar_builder_widget.dart`
- `lib/data/local/character_dao.dart`
- `assets/avatar/manifest.json`
