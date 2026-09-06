import 'dart:math';
import '../../domain/map/tile_types.dart';
import 'tavern_populator.dart';

List<MapProp> generateCastleProps(DungeonMap castle) {
  final props = <MapProp>[];
  final taken = <String>{};

  // 1. Grand Throne Room (room 0)
  final throneRoom = castle.rooms.firstWhere((r) => r.id == 0, orElse: () => castle.rooms.first);
  final thronePos = Point(throneRoom.centerX, throneRoom.y + 2);
  props.add(MapProp(
    pos: thronePos,
    asset: 'assets/tiles/prop_throne.png',
    isSolid: true,
    name: 'The Golden Lion Throne',
    interactionText: 'Carved from solid iron-oak and gilded in gold leaf, this seat of imperial sovereignty commands absolute respect across the realm.',
  ));
  taken.add('${thronePos.x},${thronePos.y}');

  // 2. Thematic Castle Hall Props
  for (final room in castle.rooms) {
    if (room.id == 0) continue;
    final center = Point(room.centerX, room.centerY);
    final key = '${center.x},${center.y}';
    if (taken.contains(key)) continue;

    switch (room.id) {
      case 1: // Banquet & Feast Hall
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_table.png',
          isSolid: true,
          name: 'Royal Mahogany Banquet Table',
          interactionText: 'A banquet table laden with silver platters, spiced pheasant, roasted venison, and crystal decanters of royal vintage.',
        ));
        taken.add(key);
        break;

      case 2: // Archmage Spire
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_crystals.png',
          isSolid: true,
          name: 'Floating Astral Focus Orb',
          interactionText: 'An iridescent celestial crystal orbiting above runic glyphs, humming with harmonic leyline energy.',
        ));
        taken.add(key);
        break;

      case 3: // Kingsguard Armory
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_weapon_rack.png',
          isSolid: true,
          name: 'Kingsguard Royal Armory Rack',
          interactionText: 'Flawlessly polished bastard swords, engraved shields, and halberds ready for castle defense.',
        ));
        taken.add(key);
        break;

      case 4: // Royal Treasury Vault
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_chest_gilded.png',
          isSolid: true,
          name: 'High Crown Bullion Vault',
          interactionText: 'A massive dragon-engraved vault chest holding minted royal platinum dragons and ancestral signet jewels.',
        ));
        taken.add(key);
        break;

      case 5: // Outer Bailey Courtyard
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_brazier.png',
          isSolid: true,
          name: 'Courtyard Signal Beacon',
          interactionText: 'A roaring copper brazier sending amber sparks up toward the stone battlements.',
        ));
        taken.add(key);
        break;
    }
  }

  // Sconces & Torches along corridors
  final rng = Random(castle.seed);
  for (int i = 0; i < 6; i++) {
    final lx = 4 + rng.nextInt(castle.width - 8);
    final ly = 4 + rng.nextInt(castle.height - 8);
    final k = '$lx,$ly';
    if (!taken.contains(k) && castle.tileAt(lx, ly) == TileType.floor) {
      props.add(MapProp(
        pos: Point(lx, ly),
        asset: 'assets/tiles/prop_torch.png',
        isSolid: false,
        name: 'Royal Sconce Torch',
        interactionText: 'A gold-trimmed sconce holding an enchanted smokeless torch.',
      ));
      taken.add(k);
    }
  }

  return props;
}

List<MapNpc> generateCastleNpcs(DungeonMap castle, {Set<String> excluding = const {}}) {
  final npcs = <MapNpc>[];
  final occupied = Set<String>.from(excluding);

  final npcsToPlace = [
    (
      id: 'npc_king_alden',
      name: 'King Alden the Just',
      role: 'Sovereign of the Realm',
      roomIndex: 0,
      dx: 0,
      dy: 0,
      portrait: 'assets/avatar/portraits/human.png',
      greeting: 'Greetings, champions of the realm. Shadows gather on our frontier borders. If your steel and spells are loyal to the crown, honor and glory await you.',
      dialogue: [
        'We pledge our swords to the defense of the realm, Your Majesty.',
        'What threats currently endanger the kingdom?',
        'Does the Crown grant boons or royal charters for our quests?',
      ],
      shop: ['Crown Royal Pardon Writ', 'Amulet of the King\'s Guard', 'Royal Elixir of Fortitude', 'Banner of Valoria'],
      canRecruit: false,
      heal: 50,
    ),
    (
      id: 'npc_marshal_cedric',
      name: 'Grand Marshal Cedric',
      role: 'Commander of the Kingsguard',
      roomIndex: 3,
      dx: 0,
      dy: 0,
      portrait: 'assets/avatar/portraits/human.png',
      greeting: 'Stand at attention! We tolerate no weak links in the castle garrison. If you seek masterwork arms or battle training, speak up.',
      dialogue: [
        'Show me the masterwork armaments forged for the Kingsguard.',
        'We need an experienced warrior commander in our vanguard.',
        'What are the defenses of the outer drawbridge gate?',
      ],
      shop: ['Valorian Bastard Sword (+1)', 'Full Plate of the Citadel', 'Tower Shield of Deflection', 'Whetstone of Keen Edge'],
      canRecruit: true,
      heal: 0,
    ),
    (
      id: 'npc_archmage_vane',
      name: 'Archmage Vane',
      role: 'Royal Court Evoker',
      roomIndex: 2,
      dx: 0,
      dy: 0,
      portrait: 'assets/avatar/portraits/elf.png',
      greeting: 'Mind the Leyline circle! Magic is not a toy for reckless squires. But for those with inquisitive minds, the secrets of the cosmos are limitless.',
      dialogue: [
        'Teach me spells to harness arcane flame and warding barriers.',
        'Have the celestial astrolabes revealed any dark omens?',
        'We would welcome your arcane mastery in our travels.',
      ],
      shop: ['Scroll of Fireball', 'Scroll of Dimension Door', 'Wand of Arcane Shielding', 'Tome of Ancient Cantrips'],
      canRecruit: true,
      heal: 20,
    ),
    (
      id: 'npc_seneschal_elion',
      name: 'Seneschal Elion',
      role: 'High Royal Steward',
      roomIndex: 1,
      dx: 1,
      dy: 1,
      portrait: 'assets/avatar/portraits/human.png',
      greeting: 'Welcome to the Feast Hall, honored guests! Fresh venison pastries and vintage honey-wine are prepared. Pray do not spill upon the imperial rugs.',
      dialogue: [
        'Who are the notable guests dining at court tonight?',
        'Can we rest and feast before our next mission?',
        'What court gossip can you share?',
      ],
      shop: ['Roasted Spiced Venison Rations', 'Royal Vintage Mead (+1 CHA)', 'Silken Courtier Cloak', 'Golden Goblet'],
      canRecruit: false,
      heal: 15,
    ),
    (
      id: 'npc_jester_pip',
      name: 'Pip the Court Jester',
      role: 'Royal Tumbler & Fool',
      roomIndex: 5,
      dx: 0,
      dy: 0,
      portrait: 'assets/avatar/portraits/halfling.png',
      greeting: 'Jingle, jangle, bells go ring! The wisest fool before the King! Want to hear a joke, or perhaps see three daggers juggle in the air?',
      dialogue: [
        'Tell us a riddle about the castle treasury.',
        'Are you faster with your wit or your daggers?',
        'Join our adventuring party; we could use some cheer.',
      ],
      shop: ['Jester\'s Lucky Bells', 'Smoke Powder Pellets', 'Deck of Illusionary Cards'],
      canRecruit: true,
      heal: 0,
    ),
    (
      id: 'npc_herald_cassian',
      name: 'Herald Cassian',
      role: 'Imperial Royal Herald',
      roomIndex: 0,
      dx: 2,
      dy: 1,
      portrait: 'assets/avatar/portraits/tiefling.png',
      greeting: 'Hear ye, hear ye! Proclamations of the Crown! Bounties are declared on dungeon lords throughout the provinces.',
      dialogue: [
        'What bounties are currently open?',
        'Announce our deeds to the King!',
      ],
      shop: ['Royal Bounty Seal (50 Gold)', 'Map of Known Dragon Lairs (75 Gold)'],
      canRecruit: false,
      heal: 0,
    ),
  ];

  for (final data in npcsToPlace) {
    if (data.roomIndex < castle.rooms.length) {
      final room = castle.rooms[data.roomIndex];
      final targetX = (room.centerX + data.dx).clamp(room.x + 1, room.x + room.w - 2);
      final targetY = (room.centerY + data.dy).clamp(room.y + 1, room.y + room.h - 2);
      final key = '$targetX,$targetY';

      if (!occupied.contains(key) && castle.tileAt(targetX, targetY).walkable) {
        npcs.add(MapNpc(
          id: data.id,
          name: data.name,
          role: data.role,
          pos: Point(targetX, targetY),
          portraitAsset: data.portrait,
          greeting: data.greeting,
          dialogueOptions: data.dialogue,
          shopItems: data.shop,
          canRecruit: data.canRecruit,
          healPower: data.heal,
        ));
        occupied.add(key);
      }
    }
  }

  return npcs;
}

List<MapAnimal> generateCastleAnimals(DungeonMap castle, {Set<String> excluding = const {}}) {
  final animals = <MapAnimal>[];
  final rng = Random(castle.seed ^ 0x4B494E47); // "KING"
  final taken = Set<String>.from(excluding);

  final archetypes = [
    ('hound', 'Royal War Mastiff', 'Heavy armored hound resting at the King\'s feet.', 'Woof! The great war mastiff wags its tail slowly and allows you to scratch behind its ear.', 'castle_hound'),
    ('owl', 'Courtyard Hunting Falcon', 'Sharp-eyed hunting bird perched on a velvet glove post.', 'Screeech! The falcon ruffles its feathers and fixes you with an alert amber gaze.', 'castle_falcon'),
    ('horse', 'Armored War Destrier', 'Massive warhorse in barded plate armor standing in the courtyard.', 'Snort! The destrier tosses its mane proudly, iron shoes clattering on the courtyard flagstones.', 'castle_horse'),
    ('cat', 'Royal Hearth Mouser', 'Sleek grey cat basking in the warm fireplace glow of the feast hall.', 'Purr... The mouser rolls over onto its back, purring contentedly.', 'castle_cat'),
  ];

  final count = 6 + rng.nextInt(3); // 6..8 animals
  for (int i = 0; i < count; i++) {
    final (species, name, flavor, dialogue, petId) = archetypes[i % archetypes.length];
    for (int attempts = 0; attempts < 30; attempts++) {
      final x = 4 + rng.nextInt(castle.width - 8);
      final y = 4 + rng.nextInt(castle.height - 8);
      final k = '$x,$y';
      if (!taken.contains(k) && castle.tileAt(x, y).walkable) {
        taken.add(k);
        animals.add(MapAnimal(
          id: 'castle_animal_${species}_$i',
          name: name,
          species: species,
          pos: Point(x, y),
          iconType: species,
          flavor: flavor,
          dialogue: dialogue,
          canAdopt: true,
          petId: petId,
        ));
        break;
      }
    }
  }

  return animals;
}
