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
  final bool isHostile;
  final int maxHp;
  final int currentHp;
  final int armorClass;
  final int attackBonus;
  final int damageDice;
  final String attackName;

  final String? greeting;
  final List<String> dialogueOptions;
  final List<String> shopItems;
  final int healPower;
  final bool canRecruit;

  const MapNpc({
    required this.id,
    required this.name,
    required this.role,
    required this.pos,
    required this.portraitAsset,
    this.isHostile = false,
    this.maxHp = 12,
    this.currentHp = 12,
    this.armorClass = 12,
    this.attackBonus = 3,
    this.damageDice = 6,
    this.attackName = 'Strike',
    this.greeting,
    this.dialogueOptions = const [],
    this.shopItems = const [],
    this.healPower = 0,
    this.canRecruit = false,
  });

  MapNpc copyWith({
    int? currentHp,
    Point? pos,
    bool? isHostile,
    String? greeting,
    List<String>? dialogueOptions,
    List<String>? shopItems,
    int? healPower,
    bool? canRecruit,
  }) {
    return MapNpc(
      id: id,
      name: name,
      role: role,
      pos: pos ?? this.pos,
      portraitAsset: portraitAsset,
      isHostile: isHostile ?? this.isHostile,
      maxHp: maxHp,
      currentHp: currentHp ?? this.currentHp,
      armorClass: armorClass,
      attackBonus: attackBonus,
      damageDice: damageDice,
      attackName: attackName,
      greeting: greeting ?? this.greeting,
      dialogueOptions: dialogueOptions ?? this.dialogueOptions,
      shopItems: shopItems ?? this.shopItems,
      healPower: healPower ?? this.healPower,
      canRecruit: canRecruit ?? this.canRecruit,
    );
  }
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

/// Three to seven tavern-goers so a bigger indoor scene never feels like a
/// blank stage. Which names/roles appear, how many, and where — all deterministic
/// from the dungeon's own seed (so revisiting the same building shows the
/// same people), but genuinely different from one building to the next
/// since every building gets its own seed (see CampaignState.seedForEnvironment).
List<MapNpc> generateTavernNpcs(DungeonMap dungeon) {
  final spots = _floorSpots(dungeon, excluding: {'${dungeon.entryPoint.x},${dungeon.entryPoint.y}'});
  if (spots.isEmpty) return [];
  final rng = Random(dungeon.seed ^ 0x4E5043);
  spots.shuffle(rng);

  final staffPick = (_staffNames.toList()..shuffle(rng)).first;
  // Patron names repeat (with a numeral suffix past the first pass) once the
  // pool is exhausted — bigger rooms call for a bigger crowd than four named
  // strangers can cover on their own.
  final patronPool = (_patronNames.toList()..shuffle(rng));
  final count = (3 + rng.nextInt(5)).clamp(1, spots.length); // 3-7 NPCs total

  final chosen = <(String, String, String)>[
    (staffPick.$1, staffPick.$2, 'assets/tiles/npc_barkeep.png'),
    for (var i = 0; i < count - 1; i++)
      (
        i < patronPool.length ? patronPool[i].$1 : '${patronPool[i % patronPool.length].$1} (${i ~/ patronPool.length + 1})',
        patronPool[i % patronPool.length].$2,
        'assets/tiles/npc_patron.png',
      ),
  ];

  final npcs = <MapNpc>[];
  for (var i = 0; i < chosen.length && i < spots.length; i++) {
    final (name, role, asset) = chosen[i];
    final isBarkeep = role.toLowerCase().contains('barkeep') || role.toLowerCase().contains('innkeeper');
    final isMerc = role.toLowerCase().contains('sellsword') || role.toLowerCase().contains('mercenary');
    final isTrader = role.toLowerCase().contains('trader') || role.toLowerCase().contains('merchant');

    npcs.add(
      MapNpc(
        id: 'npc_$i',
        name: name,
        role: role,
        pos: spots[i],
        portraitAsset: asset,
        greeting: isBarkeep
            ? "Welcome to my hearth! Rest your weary bones. What'll it be—a cold tankard, hearty stew, or rumors from the road?"
            : isMerc
                ? "Looking for blade-work? My sword arm is sharp, provided your purse has the coin to match."
                : isTrader
                    ? "Care to browse my wares? Clean potions, sturdy torches, and provisions for your crawl."
                    : "The night is dark and the crypts are treacherous. Best keep your steel sharp.",
        dialogueOptions: isBarkeep
            ? [
                "What rumors have you heard from the Whispering Crypts?",
                "Pour me a tankard of your finest spiced ale.",
                "Who's that suspicious stranger sitting in the shadows?",
              ]
            : [
                "Have you traveled the roads north of here?",
                "What dangers lurk in the nearby ruins?",
                "Join our party for an expedition into the crypts.",
              ],
        shopItems: isBarkeep
            ? ["Spiced Dwarven Stout", "Roasted Boar Shank", "Potion of Healing"]
            : isTrader
                ? ["Potion of Healing", "Torch Pack", "Antidote Flask", "Elixir of Vitality"]
                : const [],
        healPower: isBarkeep ? 6 : 0,
        canRecruit: isMerc,
      ),
    );
  }
  return npcs;
}

/// Five to twelve furniture pieces scattered around the room — count and
/// exact placement vary by seed so no two buildings feel identically staged.
List<MapProp> generateTavernProps(DungeonMap dungeon, List<MapNpc> npcs) {
  final taken = {'${dungeon.entryPoint.x},${dungeon.entryPoint.y}', ...npcs.map((n) => '${n.pos.x},${n.pos.y}')};
  final spots = _floorSpots(dungeon, excluding: taken);
  if (spots.isEmpty) return [];
  final rng = Random(dungeon.seed ^ 0x50524F50);
  spots.shuffle(rng);
  final count = (5 + rng.nextInt(8)).clamp(0, spots.length); // 5-12 props
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
