import 'dart:math';
import '../../domain/map/tile_types.dart';
import 'tavern_populator.dart' show MapProp, MapNpc;

// Dungeon corridors/rooms had zero decoration before this — just repeating
// wall/floor tiles for however big the generated map happened to be, which
// only got more glaringly empty as maps got bigger. These are scattered the
// same way tavern furniture is: deterministic from the dungeon's own seed,
// so revisiting a dungeon shows the same debris in the same spots, but a
// different dungeon (different seed) gets a genuinely different scattering.
const _dungeonPropAssets = [
  'assets/tiles/prop_torch.png',
  'assets/tiles/prop_rubble.png',
  'assets/tiles/prop_bones.png',
  'assets/tiles/prop_chest.png',
  'assets/tiles/prop_pillar.png',
  'assets/tiles/prop_moss.png',
];

/// Eight to eighteen decorations scattered across the dungeon's rooms —
/// scales with how many rooms the generated layout actually has, so a
/// sprawling multi-room dungeon reads as a lived-in ruin, not endless bare
/// stone corridors.
List<MapProp> generateDungeonProps(DungeonMap dungeon) {
  final taken = {'${dungeon.entryPoint.x},${dungeon.entryPoint.y}'};
  final spots = _floorSpots(dungeon, excluding: taken);
  if (spots.isEmpty) return [];
  final rng = Random(dungeon.seed ^ 0x44554E47); // "DUNG"
  spots.shuffle(rng);
  final target = (dungeon.rooms.length * (1 + rng.nextInt(2)) + 4).clamp(8, 18);
  final count = target.clamp(0, spots.length);
  final props = <MapProp>[];

  // Guaranteed ancient altar in one of the deeper rooms
  if (dungeon.rooms.length > 2 && spots.isNotEmpty) {
    final altarRoom = dungeon.rooms[dungeon.rooms.length ~/ 2];
    final altarPos = Point(altarRoom.centerX, altarRoom.centerY);
    props.add(MapProp(
      pos: altarPos,
      asset: 'assets/tiles/prop_altar.png',
      isSolid: true,
      name: 'Runic Stone Shrine',
      interactionText: 'An ominous stone shrine carved with elder draconic runes. Kneeling here fills your spirit with renewed courage.',
    ));
    taken.add('${altarPos.x},${altarPos.y}');
  }

  for (var i = 0; i < count && spots.isNotEmpty; i++) {
    final spot = spots.removeLast();
    final asset = _dungeonPropAssets[rng.nextInt(_dungeonPropAssets.length)];
    final isPillar = asset.contains('pillar');
    final isTorch = asset.contains('torch');
    final isChest = asset.contains('chest');
    final isBones = asset.contains('bones');
    final isRubble = asset.contains('rubble');

    props.add(MapProp(
      pos: spot,
      asset: asset,
      isSolid: isPillar,
      name: isPillar
          ? 'Fluted Stone Pillar'
          : isTorch
              ? 'Torch Sconce'
              : isChest
                  ? 'Weathered Iron Chest'
                  : isBones
                      ? 'Fallen Adventurer Skeletal Remains'
                      : isRubble
                          ? 'Crumbling Masonry Rubble'
                          : 'Luminescent Cave Moss',
      interactionText: isPillar
          ? 'A massive fluted pillar supporting the subterranean vaulted ceiling.'
          : isTorch
              ? 'A glowing torch illuminating damp obsidian walls.'
              : isChest
                  ? 'An iron-reinforced chest with a heavy brass clasp.'
                  : isBones
                      ? 'The ancient bones of an explorer who succumbed to the crypt\'s perils.'
                      : isRubble
                          ? 'Broken flagstones and shattered masonry.'
                          : 'Gently glowing cave moss pulsing with cold verdant light.',
    ));
  }
  if (dungeon.rooms.length > 1) {
    final exitRoom = dungeon.rooms.last;
    props.add(MapProp(
      pos: Point(exitRoom.centerX, exitRoom.centerY),
      asset: 'assets/tiles/prop_pillar.png',
      isSolid: true,
      name: 'Central Vault Pillar',
      interactionText: 'A monolithic carved stone pillar marking the depth descent.',
    ));
  }
  return props;
}

class _MonsterArchetype {
  final String name;
  final String role;
  final String portraitAsset;
  final int hp;
  final int ac;
  final int attackBonus;
  final int damageDice;
  final String attackName;
  const _MonsterArchetype({
    required this.name,
    required this.role,
    required this.portraitAsset,
    required this.hp,
    required this.ac,
    required this.attackBonus,
    required this.damageDice,
    required this.attackName,
  });
}

const _monsterArchetypes = [
  _MonsterArchetype(
    name: 'Skeleton Sentry',
    role: 'Undead Guardian',
    portraitAsset: 'assets/tiles/prop_bones.png',
    hp: 12,
    ac: 13,
    attackBonus: 4,
    damageDice: 6,
    attackName: 'Rusted Scythe',
  ),
  _MonsterArchetype(
    name: 'Goblin Skulker',
    role: 'Cave Raider',
    portraitAsset: 'assets/avatar/portraits/halfling.png',
    hp: 10,
    ac: 14,
    attackBonus: 4,
    damageDice: 6,
    attackName: 'Jagged Dagger',
  ),
  _MonsterArchetype(
    name: 'Orc Marauder',
    role: 'Brute',
    portraitAsset: 'assets/avatar/portraits/orc.png',
    hp: 18,
    ac: 13,
    attackBonus: 5,
    damageDice: 8,
    attackName: 'Iron Cleaver',
  ),
  _MonsterArchetype(
    name: 'Shadow Cultist',
    role: 'Acolyte of Shadows',
    portraitAsset: 'assets/avatar/portraits/tiefling.png',
    hp: 14,
    ac: 12,
    attackBonus: 4,
    damageDice: 8,
    attackName: 'Dark Pulse',
  ),
];

/// Populates dungeon chambers with hostile tactical encounters.
/// Spawns 3 to 6 monsters strategically in non-entry rooms so the starting
/// room remains safe upon descent.
List<MapNpc> generateDungeonEnemies(DungeonMap dungeon, {Set<String> excluding = const {}}) {
  if (dungeon.rooms.length <= 1) return [];
  final rng = Random(dungeon.seed ^ 0x4D4F4E53); // "MONS"
  final enemies = <MapNpc>[];
  final occupied = Set<String>.from(excluding)..add('${dungeon.entryPoint.x},${dungeon.entryPoint.y}');

  int enemyCounter = 1;
  // Skip room 0 (entry chamber)
  for (var rIdx = 1; rIdx < dungeon.rooms.length; rIdx++) {
    final room = dungeon.rooms[rIdx];
    final roomSpots = <Point>[];
    for (var y = room.y + 1; y < room.y + room.h - 1; y++) {
      for (var x = room.x + 1; x < room.x + room.w - 1; x++) {
        if (x < 0 || y < 0 || x >= dungeon.width || y >= dungeon.height) continue;
        if (dungeon.tileAt(x, y) != TileType.floor) continue;
        final key = '$x,$y';
        if (occupied.contains(key)) continue;
        roomSpots.add(Point(x, y));
      }
    }
    if (roomSpots.isEmpty) continue;
    roomSpots.shuffle(rng);

    // 1 enemy per non-entry room, 40% chance of a 2nd
    final count = min(roomSpots.length, 1 + (rng.nextDouble() < 0.4 ? 1 : 0));
    for (var i = 0; i < count; i++) {
      final spot = roomSpots[i];
      occupied.add('${spot.x},${spot.y}');

      final archetype = _monsterArchetypes[rng.nextInt(_monsterArchetypes.length)];
      enemies.add(
        MapNpc(
          id: 'enemy_${enemyCounter++}',
          name: archetype.name,
          role: archetype.role,
          pos: spot,
          portraitAsset: archetype.portraitAsset,
          isHostile: true,
          maxHp: archetype.hp,
          currentHp: archetype.hp,
          armorClass: archetype.ac,
          attackBonus: archetype.attackBonus,
          damageDice: archetype.damageDice,
          attackName: archetype.attackName,
        ),
      );
    }
  }
  return enemies;
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

class _WanderingNpcArchetype {
  final String name;
  final String role;
  final String portraitAsset;
  final String greeting;
  final List<String> dialogueOptions;
  final List<String> shopItems;
  final int healPower;
  final bool canRecruit;

  const _WanderingNpcArchetype({
    required this.name,
    required this.role,
    required this.portraitAsset,
    required this.greeting,
    required this.dialogueOptions,
    this.shopItems = const [],
    this.healPower = 0,
    this.canRecruit = false,
  });
}

const _wanderingNpcArchetypes = [
  _WanderingNpcArchetype(
    name: 'Valerius the Scholar',
    role: 'Crypt Cartographer',
    portraitAsset: 'assets/avatar/portraits/human.png',
    greeting: 'Hail, fellow traveler! The stone carvings here predate the modern age. Keep your eyes sharp for pressure plates.',
    dialogueOptions: [
      'Have you discovered any hidden pathways or treasure vaults?',
      'What advice can you offer for navigating these crypts?',
      'Do you have any surplus mapping tools or potions to spare?',
    ],
    shopItems: ['Potion of Healing', 'Torch Pack', 'Antidote Flask'],
    canRecruit: true,
  ),
  _WanderingNpcArchetype(
    name: 'Sylvi Coldwhisper',
    role: 'Wandering Apothecary',
    portraitAsset: 'assets/avatar/portraits/elf.png',
    greeting: 'The herbs of the upper vale grow well in mossy dampness. Are you in need of draughts to keep your blade arm steady?',
    dialogueOptions: [
      'What elixirs have you concocted down here?',
      'Have you encountered any foul abominations in the lower chambers?',
      'Can you mend our wounded party before we delve deeper?',
    ],
    shopItems: ['Potion of Healing', 'Potion of Greater Healing', 'Elixir of Vitality', 'Mana Phial'],
    healPower: 8,
    canRecruit: false,
  ),
  _WanderingNpcArchetype(
    name: 'Brother Joshua',
    role: 'Lost Cleric',
    portraitAsset: 'assets/avatar/portraits/dwarf.png',
    greeting: 'By the sacred light! Living companions in this tomb. May my blessing shield your courage against the dark.',
    dialogueOptions: [
      'Please impart a blessing upon our party.',
      'What consecrated spirits or holy relics were buried here?',
      'Will you join us in cleansing these chambers?',
    ],
    shopItems: ['Holy Water Flask', 'Potion of Healing'],
    healPower: 12,
    canRecruit: true,
  ),
  _WanderingNpcArchetype(
    name: 'Morren Quickstep',
    role: 'Tomb Scavenger',
    portraitAsset: 'assets/avatar/portraits/halfling.png',
    greeting: 'Quiet your steps! Heavy armor clangs like church bells in these tunnels. Looking to trade or hire some stealthy hands?',
    dialogueOptions: [
      'What traps have you spotted in the corridors ahead?',
      'Can you pick heavy iron locks or spring hidden levers?',
      'Fight beside us and we will split the dungeon spoils.',
    ],
    shopItems: ['Lockpick Kit', 'Smokebomb', 'Dagger of Keen Edge'],
    canRecruit: true,
  ),
];

/// Generates friendly and neutral interactive adventurers, merchants, and clerics
/// roaming the dungeon corridors and chambers.
List<MapNpc> generateDungeonRoamingNpcs(DungeonMap dungeon, {Set<String> excluding = const {}}) {
  if (dungeon.rooms.length <= 1) return [];
  final rng = Random(dungeon.seed ^ 0x57414E44); // "WAND"
  final npcs = <MapNpc>[];
  final occupied = Set<String>.from(excluding)..add('${dungeon.entryPoint.x},${dungeon.entryPoint.y}');

  final spots = _floorSpots(dungeon, excluding: occupied);
  if (spots.isEmpty) return [];
  spots.shuffle(rng);

  final archetypes = List.of(_wanderingNpcArchetypes)..shuffle(rng);
  final spawnCount = min(spots.length, (2 + (rng.nextDouble() < 0.5 ? 1 : 0)).clamp(2, archetypes.length));

  for (var i = 0; i < spawnCount; i++) {
    final spot = spots[i];
    occupied.add('${spot.x},${spot.y}');
    final arch = archetypes[i % archetypes.length];

    npcs.add(
      MapNpc(
        id: 'roaming_npc_$i',
        name: arch.name,
        role: arch.role,
        pos: spot,
        portraitAsset: arch.portraitAsset,
        isHostile: false,
        maxHp: 16,
        currentHp: 16,
        armorClass: 13,
        attackBonus: 4,
        damageDice: 6,
        attackName: 'Sidearm Strike',
        greeting: arch.greeting,
        dialogueOptions: arch.dialogueOptions,
        shopItems: arch.shopItems,
        healPower: arch.healPower,
        canRecruit: arch.canRecruit,
      ),
    );
  }

  return npcs;
}

