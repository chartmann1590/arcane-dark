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

/// A decorative or interactive prop placed on a floor tile.
/// [isSolid] determines whether player/NPC movement is blocked so characters
/// never walk on top of tables, counters, or solid barricades.
class MapProp {
  final Point pos;
  final String asset;
  final bool isSolid;
  final String? name;
  final String? interactionText;

  const MapProp({
    required this.pos,
    required this.asset,
    this.isSolid = true,
    this.name,
    this.interactionText,
  });

  MapProp copyWith({
    Point? pos,
    String? asset,
    bool? isSolid,
    String? name,
    String? interactionText,
  }) {
    return MapProp(
      pos: pos ?? this.pos,
      asset: asset ?? this.asset,
      isSolid: isSolid ?? this.isSolid,
      name: name ?? this.name,
      interactionText: interactionText ?? this.interactionText,
    );
  }
}

/// A wild or domestic animal roaming maps independently with interactive actions.
class MapAnimal {
  final String id;
  final String name;
  final String species;
  final Point pos;
  final String iconType; // 'hound', 'cat', 'wolf', 'owl', 'fox', 'bat'
  final String flavor;
  final String dialogue;
  final bool canAdopt;
  final String petId;

  const MapAnimal({
    required this.id,
    required this.name,
    required this.species,
    required this.pos,
    required this.iconType,
    required this.flavor,
    required this.dialogue,
    this.canAdopt = true,
    required this.petId,
  });

  MapAnimal copyWith({Point? pos}) {
    return MapAnimal(
      id: id,
      name: name,
      species: species,
      pos: pos ?? this.pos,
      iconType: iconType,
      flavor: flavor,
      dialogue: dialogue,
      canAdopt: canAdopt,
      petId: petId,
    );
  }

  String get emoji {
    switch (iconType) {
      case 'hound':
        return '🐕';
      case 'cat':
        return '🐈';
      case 'wolf':
        return '🐺';
      case 'owl':
        return '🦉';
      case 'fox':
        return '🦊';
      case 'bat':
        return '🦇';
      default:
        return '🐾';
    }
  }
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

/// Rich furniture pieces scattered around the room — including bar counter,
/// oak tables, barrels, bookshelves, weapon racks, velvet rugs, chairs, and hearth campfires.
List<MapProp> generateTavernProps(DungeonMap dungeon, List<MapNpc> npcs) {
  final taken = {'${dungeon.entryPoint.x},${dungeon.entryPoint.y}', ...npcs.map((n) => '${n.pos.x},${n.pos.y}')};
  final spots = _floorSpots(dungeon, excluding: taken);
  if (spots.isEmpty) return [];
  final rng = Random(dungeon.seed ^ 0x50524F50);
  spots.shuffle(rng);

  final props = <MapProp>[];

  // Guaranteed Bar Counter & Stools near center
  if (spots.isNotEmpty) {
    props.add(MapProp(
      pos: spots.removeLast(),
      asset: 'assets/tiles/prop_bar_counter.png',
      isSolid: true,
      name: 'Oak Bar Counter',
      interactionText: 'A sturdy carved oak counter polished smooth with centuries of spilled spiced mead.',
    ));
  }

  // Cozy Campfire / Hearth
  if (spots.isNotEmpty) {
    props.add(MapProp(
      pos: spots.removeLast(),
      asset: 'assets/tiles/prop_campfire.png',
      isSolid: false,
      name: 'Crackling Hearth Fire',
      interactionText: 'A blazing stone hearth radiating comforting warmth and dancing amber embers.',
    ));
  }

  // Ancient Lore Bookshelf
  if (spots.isNotEmpty) {
    props.add(MapProp(
      pos: spots.removeLast(),
      asset: 'assets/tiles/prop_bookshelf.png',
      isSolid: true,
      name: 'Innkeeper\'s Bookshelf',
      interactionText: 'Filled with weathered travelers\' journals, leather-bound songbooks, and old regional maps.',
    ));
  }

  // Weapon Rack
  if (spots.isNotEmpty) {
    props.add(MapProp(
      pos: spots.removeLast(),
      asset: 'assets/tiles/prop_weapon_rack.png',
      isSolid: true,
      name: 'Armory Rack',
      interactionText: 'Racks holding polished iron blades, cross-spears, and notched heater shields.',
    ));
  }

  // Decorative Velvet Rug
  if (spots.isNotEmpty) {
    props.add(MapProp(
      pos: spots.removeLast(),
      asset: 'assets/tiles/prop_rug.png',
      isSolid: false,
      name: 'Woven Velvet Rug',
      interactionText: 'An intricate dwarven-woven wool runner bearing the seal of ancient clan masters.',
    ));
  }

  // Additional tables and barrels
  final additionalCount = (4 + rng.nextInt(6)).clamp(0, spots.length);
  for (var i = 0; i < additionalCount; i++) {
    final spot = spots.removeLast();
    final roll = rng.nextInt(4);
    if (roll == 0) {
      props.add(MapProp(
        pos: spot,
        asset: 'assets/tiles/prop_table.png',
        isSolid: true,
        name: 'Tavern Table',
        interactionText: 'A heavy pine table bearing candle wax, clay mugs, and dice gouges.',
      ));
    } else if (roll == 1) {
      props.add(MapProp(
        pos: spot,
        asset: 'assets/tiles/prop_barrel.png',
        isSolid: true,
        name: 'Ale Cask',
        interactionText: 'A banded oak cask sealed tight, smelling strongly of dark malted porter.',
      ));
    } else if (roll == 2) {
      props.add(MapProp(
        pos: spot,
        asset: 'assets/tiles/prop_chair.png',
        isSolid: false,
        name: 'Wooden Stool',
        interactionText: 'A simple carved stool pulled close to the tavern fire.',
      ));
    } else {
      props.add(MapProp(
        pos: spot,
        asset: 'assets/tiles/prop_torch.png',
        isSolid: false,
        name: 'Wall Sconce Torch',
        interactionText: 'A pitch torch casting flickering orange warmth across the floorboards.',
      ));
    }
  }

  return props;
}

/// Generates friendly domestic animals roaming the tavern hearth.
List<MapAnimal> generateTavernAnimals(DungeonMap dungeon, {required Set<String> excluding}) {
  final spots = _floorSpots(dungeon, excluding: excluding);
  if (spots.length < 2) return [];
  final rng = Random(dungeon.seed ^ 0x414E494D); // "ANIM"
  spots.shuffle(rng);

  return [
    MapAnimal(
      id: 'animal_hound',
      name: 'Barnaby the Tavern Hound',
      species: 'Golden Tavern Hound',
      pos: spots[0],
      iconType: 'hound',
      flavor: 'A friendly golden hound who trots around table legs, wagging his tail happily at everyone.',
      dialogue: 'Woof! Barnaby leans his warm head against your hand and pants enthusiastically.',
      canAdopt: true,
      petId: 'tavern_hound',
    ),
    MapAnimal(
      id: 'animal_cat',
      name: 'Milo the Hearth Cat',
      species: 'Calico Hearth Feline',
      pos: spots[1],
      iconType: 'cat',
      flavor: 'A sleek calico cat perched comfortably near the warm hearth, lazily watching shadows.',
      dialogue: 'Purrr... Milo stretches his paws, rubs against your greaves, and lets out a soft trill.',
      canAdopt: true,
      petId: 'hearth_cat',
    ),
  ];
}

/// Generates wild animals roaming dungeon ruins and caverns.
List<MapAnimal> generateDungeonAnimals(DungeonMap dungeon, {required Set<String> excluding}) {
  if (dungeon.rooms.length < 2) return [];
  final spots = _floorSpots(dungeon, excluding: excluding);
  if (spots.isEmpty) return [];
  final rng = Random(dungeon.seed ^ 0x57494C44); // "WILD"
  spots.shuffle(rng);

  final animals = <MapAnimal>[];
  final archetypes = [
    (
      'Frostfur',
      'Shadow Wolf Pup',
      'wolf',
      'A sleek midnight wolf pup with silver eyes, watching your torches with curious intelligence.',
      'A soft growl turns into an inquisitive whimper as it smells your provisions.',
      'shadow_wolf',
    ),
    (
      'Nocturna',
      'Spectral Screech Owl',
      'owl',
      'A luminous horned owl perched on a stone pillar, swiveling its head with piercing amber gaze.',
      'Hoo-hoo... The spectral owl rustles its shimmering feathers and studies your soul.',
      'spectral_owl',
    ),
    (
      'Ember',
      'Highland Ember Fox',
      'fox',
      'A nimble crimson fox with large alert ears and a bushy snow-tipped tail darting through the rocks.',
      'The fox chirps curiously and cocks its head, intrigued by your gleaming equipment.',
      'astral_falcon',
    ),
  ];

  final count = min(2, spots.length);
  for (var i = 0; i < count; i++) {
    final t = archetypes[i % archetypes.length];
    animals.add(
      MapAnimal(
        id: 'wild_animal_$i',
        name: '${t.$1} the ${t.$2}',
        species: t.$2,
        pos: spots[i],
        iconType: t.$3,
        flavor: t.$4,
        dialogue: t.$5,
        canAdopt: true,
        petId: t.$6,
      ),
    );
  }
  return animals;
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
