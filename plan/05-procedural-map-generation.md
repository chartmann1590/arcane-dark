# Phase 05 — Procedural Map Generation

**Goal:** Seeded, deterministic procedural dungeon and overworld maps rendered as a 2D tile grid (via Flame), with AI-assisted placement of encounters, loot, and points of interest so maps feel authored rather than purely random.

**Depends on:** Phase 01 (app shell, Flame added to `pubspec.yaml`), Phase 02 (model service, for AI-assisted placement). Phase 07's mockup for this screen is done: Main Gameplay Screen (`projects/6748340587166257171/screens/0c7b23c25db94929bb4df57fd9d56dc7`) — see `07-ui-design-stitch.md`'s Screen registry.
**Enables:** Phase 03 (DM engine needs to know party position/current room to narrate accurately), Phase 06 (multiplayer party members share one map instance).

## Tasks

### 1. Add Flame and a minimal tilemap
- Add `flame` and `flame_tiled` (or hand-rolled tile grid if Tiled-format maps aren't needed — for procedurally generated content, a custom `TileGrid` class is simpler than authoring `.tmx` files) to `pubspec.yaml`.
- Build a `GameMapWidget` that embeds a `FlameGame` inside the Flutter widget tree on the `/play` route, rendering a scrollable/zoomable camera over a tile grid.

### 2. Deterministic dungeon generator (pure algorithm, no AI)
- Implement a classic **BSP (binary space partition) room-and-corridor generator**: given a seed (int) and grid dimensions, recursively split the grid into sub-regions, carve a room in each leaf, connect sibling rooms with corridors.
```dart
class DungeonGenerator {
  DungeonMap generate({required int seed, required int width, required int height});
}
class DungeonMap {
  List<List<TileType>> tiles; // floor, wall, door, water, etc.
  List<Room> rooms;
  Point entryPoint;
}
```
- This must be 100% deterministic given the same seed — write a unit test asserting two generations with the same seed produce identical tile grids.
- Also implement a simpler **overworld generator** (Perlin/simplex noise heightmap → biome tiles: forest/plains/mountain/water) for non-dungeon exploration, reusing the same `TileType` grid abstraction.

### 3. AI-assisted encounter/loot placement
- After the deterministic generator produces room layout, make **one** model call (not per-room, to control latency/battery) asking Gemma to distribute a fixed budget of encounters/loot/points-of-interest across the room list, given: room sizes, room adjacency, and the current campaign's tone/seed from Phase 03.
- Constrain output the same way as Phase 03 (rigid `<<PLACE: type=encounter room=4 detail="goblin ambush">>` line format, not JSON) for reliability on a small model.
- If the model call fails or times out, fall back to a deterministic placement heuristic (e.g. one encounter per 3 rooms, loot in dead-end rooms) — **the map must always be playable even with zero AI involvement**, since AI-assisted placement is a quality enhancement, not a hard dependency.

### 4. Render the map
- `TileType` → sprite mapping via a `TileRenderMap` (uses placeholder colored squares until Phase 07 delivers tile art; swapping is asset-manifest-driven like Phase 04's avatar layers).
- Party token(s) rendered on top of the tile layer, moved via tap-to-move (pathfind with A* over walkable tiles) or a virtual joystick — pick tap-to-move for MVP, it's simpler to implement correctly and fits turn-based D&D pacing better than real-time movement.
- Fog of war: tiles not yet visited render darkened/hidden; reveal on visit. Store visited-tile state per campaign so returning to a dungeon later shows explored areas.

### 5. Wire into `CampaignState`
- Extend Phase 03's `CampaignState` with `currentMapId`, `partyPosition`, `visitedTiles`.
- The DM engine's `move_party` tool call (Phase 03) triggers pathfinding + position update here, and the DM's narration prompt includes a short text description of the current room (auto-generated from tile/room metadata, e.g. "a damp 10x10 stone chamber with a cracked altar") so the model narrates the actual map rather than an imagined one.

## Acceptance criteria

- [ ] Same seed always produces an identical dungeon layout (unit test enforced).
- [ ] A generated dungeon is always fully connected (every room reachable from the entry point) — unit test with flood-fill reachability check.
- [ ] Map renders and pans/zooms smoothly on a mid-range Android device.
- [ ] Tap-to-move correctly pathfinds around walls.
- [ ] AI placement failure (simulate by disabling the model) still yields a playable map via the deterministic fallback.
- [ ] Fog of war persists correctly across app restarts (visited tiles saved).

## Key files

- `lib/domain/map/dungeon_generator.dart`
- `lib/domain/map/overworld_generator.dart`
- `lib/domain/map/tile_types.dart`
- `lib/features/play/game_map_widget.dart` (Flame integration)
- `lib/domain/map/ai_placement.dart`
- `assets/tiles/manifest.json`
