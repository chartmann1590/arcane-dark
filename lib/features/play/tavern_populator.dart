import 'dart:math';
import '../../domain/map/tile_types.dart';

/// A named NPC standing at a fixed spot on an indoor map — deterministic
/// from the dungeon's own seed, so the same building always has the same
/// people in the same corners instead of an empty room, but a *different*
/// building (different seed) gets a different cast.
class MapNpc {
  final String id;
  final String name;
  final String role;
  final Point pos;
  final String portraitAsset;
  const MapNpc({required this.id, required this.name, required this.role, required this.pos, required this.portraitAsset});
}

/// A purely decorative prop (table, barrel, bar counter) placed on a floor
/// tile — makes an interior read as furnished instead of empty stone/wood.
class MapProp {
  final Point pos;
  final String asset;
  const MapProp({required this.pos, required this.asset});
}

// Two portrait art styles exist today — "staff" (friendly, working the
// room) and "patron" (a stranger just passing through) — each covering a
// pool of names/roles so the same two pieces of art still read as a varied
// cast of people from one building to the next.
const _staffNames = [
  ('Bramwell', 'Barkeep'),
  ('Old Sella', 'Innkeeper'),
  ('Tolvar', 'Cook'),
  ('Marta Ashwell', 'Quartermaster'),
];
const _patronNames = [
  ('A Hooded Stranger', 'Patron'),
  ('Kessic the Wanderer', 'Traveler'),
  ('A Weary Mercenary', 'Sellsword'),
  ('Old Fenn', 'Regular'),
  ('A Nervous Merchant', 'Trader'),
];

const _propAssets = ['assets/tiles/prop_bar_counter.png', 'assets/tiles/prop_table.png', 'assets/tiles/prop_barrel.png'];

/// One to three tavern-goers so an indoor scene never feels like a blank
/// stage. Which names/roles appear, how many, and where — all deterministic
/// from the dungeon's own seed (so revisiting the same building shows the
/// same people), but genuinely different from one building to the next
/// since every building gets its own seed (see CampaignState.seedForEnvironment).
List<MapNpc> generateTavernNpcs(DungeonMap dungeon) {
  final spots = _floorSpots(dungeon, excluding: {'${dungeon.entryPoint.x},${dungeon.entryPoint.y}'});
  if (spots.isEmpty) return [];
  final rng = Random(dungeon.seed ^ 0x4E5043);
  spots.shuffle(rng);

  final staffPick = (_staffNames.toList()..shuffle(rng)).first;
  final patronPicks = (_patronNames.toList()..shuffle(rng));
  final count = 1 + rng.nextInt(3); // 1-3 NPCs total

  final chosen = <(String, String, String)>[
    (staffPick.$1, staffPick.$2, 'assets/tiles/npc_barkeep.png'),
    for (final p in patronPicks.take(count - 1)) (p.$1, p.$2, 'assets/tiles/npc_patron.png'),
  ];

  final npcs = <MapNpc>[];
  for (var i = 0; i < chosen.length && i < spots.length; i++) {
    final (name, role, asset) = chosen[i];
    npcs.add(MapNpc(id: 'npc_$i', name: name, role: role, pos: spots[i], portraitAsset: asset));
  }
  return npcs;
}

/// Two to five furniture pieces scattered around the room — count and
/// exact placement vary by seed so no two buildings feel identically staged.
List<MapProp> generateTavernProps(DungeonMap dungeon, List<MapNpc> npcs) {
  final taken = {'${dungeon.entryPoint.x},${dungeon.entryPoint.y}', ...npcs.map((n) => '${n.pos.x},${n.pos.y}')};
  final spots = _floorSpots(dungeon, excluding: taken);
  if (spots.isEmpty) return [];
  final rng = Random(dungeon.seed ^ 0x50524F50);
  spots.shuffle(rng);
  final count = (2 + rng.nextInt(4)).clamp(0, spots.length); // 2-5 props
  final props = <MapProp>[];
  for (var i = 0; i < count; i++) {
    props.add(MapProp(pos: spots[i], asset: _propAssets[rng.nextInt(_propAssets.length)]));
  }
  return props;
}

List<Point> _floorSpots(DungeonMap dungeon, {required Set<String> excluding}) {
  final spots = <Point>[];
  for (final room in dungeon.rooms) {
    for (var y = room.y; y < room.y + room.h; y++) {
      for (var x = room.x; x < room.x + room.w; x++) {
        if (x < 0 || y < 0 || x >= dungeon.width || y >= dungeon.height) continue;
        if (dungeon.tileAt(x, y) != TileType.floor) continue;
        final key = '$x,$y';
        if (excluding.contains(key)) continue;
        spots.add(Point(x, y));
      }
    }
  }
  return spots;
}
