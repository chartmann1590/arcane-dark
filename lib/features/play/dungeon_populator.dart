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
  'assets/tiles/prop_brazier.png',
  'assets/tiles/prop_statue.png',
  'assets/tiles/prop_crystals.png',
  'assets/tiles/prop_crates.png',
];

/// Generates thematic room centerpiece props matching each room's RoomType,
/// alongside ambient torches, rubble, and moss scattered across corridors.
List<MapProp> generateDungeonProps(DungeonMap dungeon) {
  final taken = {'${dungeon.entryPoint.x},${dungeon.entryPoint.y}'};
  final props = <MapProp>[];
  final rng = Random(dungeon.seed ^ 0x44554E47); // "DUNG"

  // 1. Thematic Centerpiece Props for each room
  for (final room in dungeon.rooms) {
    final center = Point(room.centerX, room.centerY);
    final centerKey = '${center.x},${center.y}';
    if (taken.contains(centerKey)) continue;

    switch (room.type) {
      case RoomType.entryVestibule:
        final torchPos = Point(room.x + 1, room.y + 1);
        if (!taken.contains('${torchPos.x},${torchPos.y}')) {
          props.add(MapProp(
            pos: torchPos,
            asset: 'assets/tiles/prop_torch.png',
            isSolid: false,
            name: 'Vestibule Wall Torch',
            interactionText: 'A torch flickering brightly at the entrance steps, illuminating the way down.',
          ));
          taken.add('${torchPos.x},${torchPos.y}');
        }
        break;

      case RoomType.alchemistLab:
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_cauldron.png',
          isSolid: true,
          name: 'Bubbling Alchemical Cauldron',
          interactionText: 'A blackened iron cauldron bubbling with glowing emerald brew. Sweet and herbal vapors restore vitality, and inspecting the cauldron yields an elixir.',
        ));
        taken.add(centerKey);
        final crystalPos = Point(room.x + 1, room.y + 1);
        if (!taken.contains('${crystalPos.x},${crystalPos.y}')) {
          props.add(MapProp(
            pos: crystalPos,
            asset: 'assets/tiles/prop_crystals.png',
            isSolid: false,
            name: 'Alchemical Mana Crystal',
            interactionText: 'Luminescent mana crystals used to distill volatile arcane reagents.',
          ));
          taken.add('${crystalPos.x},${crystalPos.y}');
        }
        break;

      case RoomType.ancientLibrary:
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_lectern.png',
          isSolid: true,
          name: 'Arcane Runic Lectern',
          interactionText: 'A carved wooden lectern holding an ancient grimoire pulsing with glowing planar runes. Deciphering it grants deep arcane insight.',
        ));
        taken.add(centerKey);
        final shelfPos = Point(room.x + 1, room.y + 1);
        if (!taken.contains('${shelfPos.x},${shelfPos.y}')) {
          props.add(MapProp(
            pos: shelfPos,
            asset: 'assets/tiles/prop_bookshelf.png',
            isSolid: true,
            name: 'Archive Bookshelf',
            interactionText: 'Dusty stone shelves holding treatises on planar binding, forgotten dialects, and star charts.',
          ));
          taken.add('${shelfPos.x},${shelfPos.y}');
        }
        break;

      case RoomType.armory:
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_weapon_rack.png',
          isSolid: true,
          name: 'Old Vanguard Weapon Rack',
          interactionText: 'A stout timber rack stacked with steel broadswords, crossguards, and iron kite shields from the crypt vanguard.',
        ));
        taken.add(centerKey);
        final cratesPos = Point(room.x + 1, room.y + 1);
        if (!taken.contains('${cratesPos.x},${cratesPos.y}')) {
          props.add(MapProp(
            pos: cratesPos,
            asset: 'assets/tiles/prop_crates.png',
            isSolid: true,
            name: 'Armory Storage Munitions',
            interactionText: 'Heavy timber crates and iron-hooped barrels filled with oil, whetstones, and crossbow bolts.',
          ));
          taken.add('${cratesPos.x},${cratesPos.y}');
        }
        break;

      case RoomType.floodedCrypt:
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_sarcophagus.png',
          isSolid: true,
          name: 'Carved Stone Sarcophagus',
          interactionText: 'An ancient limestone tomb etched with funerary death masks. Prying the lid requires strength, but may hold sacred burial relics.',
        ));
        taken.add(centerKey);
        final bonesPos = Point(room.x + 1, room.y + 1);
        if (!taken.contains('${bonesPos.x},${bonesPos.y}')) {
          props.add(MapProp(
            pos: bonesPos,
            asset: 'assets/tiles/prop_bones.png',
            isSolid: false,
            name: 'Crypt Skeletal Remains',
            interactionText: 'The bleached bones of an ancient sentinel guarding the tomb.',
          ));
          taken.add('${bonesPos.x},${bonesPos.y}');
        }
        break;

      case RoomType.shrineSanctum:
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_altar.png',
          isSolid: true,
          name: 'Sanctuary of the Silver Flame',
          interactionText: 'A consecrated runic altar radiating serene warmth. Kneeling in prayer restores vitality and shields against the shadows.',
        ));
        taken.add(centerKey);
        final statuePos = Point(room.x + 1, room.y + 1);
        if (!taken.contains('${statuePos.x},${statuePos.y}')) {
          props.add(MapProp(
            pos: statuePos,
            asset: 'assets/tiles/prop_statue.png',
            isSolid: true,
            name: 'Sanctum Knight Guardian',
            interactionText: 'A solemn limestone statue of a knight with blade held reverently tip-down.',
          ));
          taken.add('${statuePos.x},${statuePos.y}');
        }
        break;

      case RoomType.treasureVault:
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_chest_gilded.png',
          isSolid: true,
          name: 'Gilded Vault Coffer',
          interactionText: 'An ornate royal coffer bound in gold filigree and locked with an intricate runic tumbler. Rare treasures await inside.',
        ));
        taken.add(centerKey);
        break;

      case RoomType.bossChamber:
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_pillar.png',
          isSolid: true,
          name: 'Monolithic Crypt Pillar',
          interactionText: 'A monolithic carved stone pillar marking the depth descent.',
        ));
        taken.add(centerKey);
        final statuePos = Point(room.x + 1, room.y + 1);
        if (!taken.contains('${statuePos.x},${statuePos.y}')) {
          props.add(MapProp(
            pos: statuePos,
            asset: 'assets/tiles/prop_statue.png',
            isSolid: true,
            name: 'Vanguard Colossus Statue',
            interactionText: 'A towering stone effigy of an ancient war-monarch standing vigil over the boss chamber.',
          ));
          taken.add('${statuePos.x},${statuePos.y}');
        }
        break;
    }
  }

  // 2. Ambient props scattered across floor spots
  final spots = _floorSpots(dungeon, excluding: taken);
  if (spots.isNotEmpty) {
    spots.shuffle(rng);
    final count = (dungeon.rooms.length * 2).clamp(6, min(14, spots.length));
    for (var i = 0; i < count && spots.isNotEmpty; i++) {
      final spot = spots.removeLast();
      final asset = _dungeonPropAssets[rng.nextInt(_dungeonPropAssets.length)];
      final isTorch = asset.contains('torch');
      final isBrazier = asset.contains('brazier');
      final isChest = asset.contains('chest');
      final isBones = asset.contains('bones');
      final isRubble = asset.contains('rubble');
      final isStatue = asset.contains('statue');
      final isCrystals = asset.contains('crystals');
      final isCrates = asset.contains('crates');

      props.add(MapProp(
        pos: spot,
        asset: asset,
        isSolid: isBrazier || isStatue || isCrates,
        name: isTorch
            ? 'Torch Sconce'
            : isBrazier
                ? 'Corridor Brazier'
                : isChest
                    ? 'Weathered Iron Chest'
                    : isBones
                        ? 'Fallen Explorer Remains'
                        : isRubble
                            ? 'Crumbling Masonry Rubble'
                            : isStatue
                                ? 'Sentinel Knight Statue'
                                : isCrystals
                                    ? 'Mana Crystal Spire'
                                    : isCrates
                                        ? 'Supply Crates & Barrel'
                                        : 'Luminescent Cave Moss',
        interactionText: isTorch
            ? 'A glowing wall torch illuminating damp stone walls.'
            : isBrazier
                ? 'A bronze basin with crackling embers warming the corridor.'
                : isChest
                    ? 'An iron-reinforced chest nestled in the crypt shadows.'
                    : isBones
                        ? 'The ancient remains of a fallen explorer.'
                        : isRubble
                            ? 'Broken flagstones and shattered masonry.'
                            : isStatue
                                ? 'A chiseled limestone statue of a crypt guardian knight.'
                                : isCrystals
                                    ? 'Prismatic mana crystals radiating arcane luminescence.'
                                    : isCrates
                                        ? 'Weathered wooden supply crates bound with iron hoop barrels.'
                                        : 'Luminescent cave moss glowing with gentle emerald light.',
      ));
    }
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
    role: 'Armored Sentry',
    portraitAsset: 'assets/tiles/prop_bones.png',
    hp: 14,
    ac: 14,
    attackBonus: 4,
    damageDice: 6,
    attackName: 'Shield Bash',
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
    role: 'Brute Berserker',
    portraitAsset: 'assets/avatar/portraits/orc.png',
    hp: 18,
    ac: 13,
    attackBonus: 5,
    damageDice: 8,
    attackName: 'Iron Cleaver',
  ),
  _MonsterArchetype(
    name: 'Shadow Cultist',
    role: 'Shadow Caster',
    portraitAsset: 'assets/avatar/portraits/tiefling.png',
    hp: 14,
    ac: 12,
    attackBonus: 4,
    damageDice: 8,
    attackName: 'Dark Siphon',
  ),
  _MonsterArchetype(
    name: 'Crypt Wraith',
    role: 'Undead Specter',
    portraitAsset: 'assets/avatar/portraits/drow.png',
    hp: 16,
    ac: 13,
    attackBonus: 5,
    damageDice: 8,
    attackName: 'Life Drain',
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
  _WanderingNpcArchetype(
    name: 'Thorna Ironbreaker',
    role: 'Dwarven Tinkerer',
    portraitAsset: 'assets/avatar/portraits/dwarf.png',
    greeting: 'Stone and steel! The masonry down here is buckling under old dwarven pressure seals. Mind your footing around the tripwires.',
    dialogueOptions: [
      'Can you help disarm any mechanical traps ahead?',
      'Do you have sturdy armaments or shield plating for trade?',
      'Lend your hammer to our party vanguard!',
    ],
    shopItems: ['Whetstone of Keen Edge', 'Heavy Iron Shield (+2 AC)', 'Dwarven Stout Ale'],
    healPower: 6,
    canRecruit: true,
  ),
  _WanderingNpcArchetype(
    name: 'Elaria Moonwhisper',
    role: 'Wayfinder Scout',
    portraitAsset: 'assets/avatar/portraits/elf.png',
    greeting: 'The winds carrying through these fissures sing of ancient vaulted sanctuaries and slumbering guardians.',
    dialogueOptions: [
      'Which corridors lead towards the central sanctuary?',
      'Have you tracked any restless spirits or shadow beasts?',
      'Join our expedition as our vanguard scout.',
    ],
    shopItems: ['Elven Trail Rations', 'Quiver of Silvered Arrows', 'Boots of Stealth'],
    healPower: 8,
    canRecruit: true,
  ),
  _WanderingNpcArchetype(
    name: 'Master Craig',
    role: 'Traveling Relic Merchant',
    portraitAsset: 'assets/avatar/portraits/human.png',
    greeting: 'Riches and curios from forgotten crypts! Gold speaks every dialect, my friends. What ancient treasure do you seek?',
    dialogueOptions: [
      'Show us your most potent enchanted wares.',
      'Have you heard rumors of legendary relics buried nearby?',
      'Will you purchase our salvaged crypt spoils?',
    ],
    shopItems: ['Ring of Feather Fall', 'Scroll of Magic Missile', 'Greater Health Draught', 'Amulet of Ward'],
    canRecruit: false,
  ),
  _WanderingNpcArchetype(
    name: 'Vael the Scavenger',
    role: 'Hollow Crypt Hermit',
    portraitAsset: 'assets/avatar/portraits/orc.png',
    greeting: 'Another foolish company delved down into the maw! Beware the red-eyed stalkers that hunt when your torch gutters.',
    dialogueOptions: [
      'What rumors or secrets can you share of this floor?',
      'Where can we find clean water or safe resting alcoves?',
      'Fight with us to clear a path to the surface!',
    ],
    shopItems: ['Smoked Meat Pack', 'Fire Starting Flint', 'Rusted Cleaver (+1 ATK)'],
    canRecruit: true,
  ),
  _WanderingNpcArchetype(
    name: 'Sister Teresa',
    role: 'Radiant Templar',
    portraitAsset: 'assets/avatar/portraits/tiefling.png',
    greeting: 'The sacred flame shall not falter in this hollow tomb. Stand firm in faith, travelers, and let darkness be purged.',
    dialogueOptions: [
      'Bestow a healing prayer upon our wounded companions.',
      'What dark magic binds the dead to these flagstones?',
      'We welcome your holy blade and radiant prayers in our party!',
    ],
    shopItems: ['Vial of Consecrated Oil', 'Potion of Greater Healing', 'Radiant Symbol'],
    healPower: 14,
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
  final spawnCount = min(spots.length, (4 + rng.nextInt(3)).clamp(4, archetypes.length));

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

