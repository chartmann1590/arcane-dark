import 'dart:math';
import '../../domain/map/tile_types.dart';
import 'tavern_populator.dart';

List<MapProp> generateCaveProps(DungeonMap cave) {
  final props = <MapProp>[];
  final rng = Random(cave.seed ^ 0x43415645); // "CAVE"
  final taken = <String>{};

  for (final room in cave.rooms) {
    final center = Point(room.centerX, room.centerY);
    final key = '${center.x},${center.y}';
    if (taken.contains(key)) continue;

    switch (room.id) {
      case 0: // Cavern Mouth / Entry
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_torch.png',
          isSolid: false,
          name: 'Prospector\'s Wall Sconce',
          interactionText: 'An iron bracket torch left by spelunkers, casting dancing embers across the damp limestone.',
        ));
        taken.add(key);
        break;

      case 1: // Crystal Geode
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_crystals.png',
          isSolid: true,
          name: 'Resonating Prismatic Crystal Geode',
          interactionText: 'A massive cluster of cerulean crystals humming with harmonic planar energy. Meditating here attunes arcane spell slots.',
        ));
        taken.add(key);
        break;

      case 2: // Sunken Lake / Fungal
        props.add(MapProp(
          pos: Point(room.x + 2, room.y + 2),
          asset: 'assets/tiles/prop_shrine.png',
          isSolid: false,
          name: 'Bioluminescent Shoreline Flora',
          interactionText: 'Glowing turquoise cave moss and fungal caps growing on subterranean riverbanks, illuminating the dark waters.',
        ));
        taken.add('${room.x + 2},${room.y + 2}');
        break;

      case 3: // Mine Excavation / Forge
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_crates.png',
          isSolid: true,
          name: 'Dwarven Ore Cart & Pickaxes',
          interactionText: 'A wooden rail cart laden with raw silver ore and discarded iron excavation tools.',
        ));
        taken.add(key);
        break;

      case 4: // Chasm Crossing / Sarcophagus
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_sarcophagus.png',
          isSolid: true,
          name: 'Prehistoric Chasm Crypt',
          interactionText: 'An ancient basalt sarcophagus etched with runes of primeval cavern dwellers.',
        ));
        taken.add(key);
        break;

      case 5: // Ancient Sanctum / Deep Caldera
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_altar.png',
          isSolid: true,
          name: 'Primordial Subterranean Altar',
          interactionText: 'A dark basalt slab carved with prehistoric glyphs of the subterranean deep gods.',
        ));
        taken.add(key);
        break;
    }
  }

  // Scattered cave props (crystals, ore carts, braziers, chests)
  final candidateTiles = <Point>[];
  for (int y = 2; y < cave.height - 2; y++) {
    for (int x = 2; x < cave.width - 2; x++) {
      if (cave.tileAt(x, y) == TileType.floor) {
        final k = '$x,$y';
        if (!taken.contains(k) && !(x == cave.entryPoint.x && y == cave.entryPoint.y)) {
          candidateTiles.add(Point(x, y));
        }
      }
    }
  }
  candidateTiles.shuffle(rng);

  final caveAssets = [
    ('assets/tiles/prop_crystals.png', 'Luminescent Crystal Shard', 'Subterranean mineral formation glowing with ambient cyan light.'),
    ('assets/tiles/prop_chest.png', 'Prospector\'s Hidden Coffer', 'An ironbound strongbox wedged into a fissure in the rock.'),
    ('assets/tiles/prop_brazier.png', 'Dwarven Heating Brazier', 'Perpetual sulfur embers keeping the cavern chill at bay.'),
    ('assets/tiles/prop_crates.png', 'Mining Supply Crates', 'Saltpeter canisters and blasting cords for cavern excavation.'),
    ('assets/tiles/prop_rubble.png', 'Fallen Stalactite Rubble', 'Jagged stone debris shattered against the cavern flagstones.'),
  ];

  for (final p in candidateTiles.take(10)) {
    final (asset, name, desc) = caveAssets[rng.nextInt(caveAssets.length)];
    props.add(MapProp(
      pos: p,
      asset: asset,
      isSolid: asset.contains('crystals') || asset.contains('chest') || asset.contains('crates'),
      name: name,
      interactionText: desc,
    ));
    taken.add('${p.x},${p.y}');
  }

  return props;
}

List<MapNpc> generateCaveNpcs(DungeonMap cave, {Set<String> excluding = const {}}) {
  final npcs = <MapNpc>[];
  final rng = Random(cave.seed ^ 0x4E504343); // "NPCC"
  final taken = Set<String>.from(excluding);

  final archetypes = [
    MapNpc(
      id: 'npc_miner_brok',
      name: 'Brok Fireforge',
      role: 'Dwarven Deep-Prospector',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/dwarf.png',
      greeting: 'Watch yer step, friend! The lower strata are unstable, but by the gods, the mithral veins here run pure!',
      dialogueOptions: [
        'Have you found any rare minerals or gems?',
        'Which tunnels lead deeper down?',
        'Can we buy tempered mining equipment?',
      ],
      shopItems: [
        'Mithral Pickaxe (+1 ATK, 45 Gold)',
        'Heavy Miner\'s Helmet (Torchlight +1 AC, 35 Gold)',
        'Rough Amethyst Gem (50 Gold)',
      ],
      healPower: 0,
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_spelunker_lyanna',
      name: 'Lyanna the Bold',
      role: 'Underdark Spelunker',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'Tread softly... sound carries for miles through these stone fissures. Something vast stirs below the chasm.',
      dialogueOptions: [
        'What manner of beasts dwell in the chasm?',
        'Can you share a map of the upper caves?',
        'Would you guide our company through the dark?',
      ],
      shopItems: [
        'Silk Climbing Rope with Grapple (15 Gold)',
        'Everburning Phosphor Lantern (30 Gold)',
        'Antidote for Cave Spider Venom (20 Gold)',
      ],
      healPower: 12,
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_goblin_snik',
      name: 'Snik the Turncoat',
      role: 'Goblin Cave Merchant',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/halfling.png',
      greeting: 'Don’t smash Snik! Snik has shiny treasures dropped by previous delvers! Cheap prices, good luck charms!',
      dialogueOptions: [
        'Show me what shiny goods you\'ve scavenged.',
        'Where do the hostile monsters nest?',
      ],
      shopItems: [
        'Snik\'s Lucky Rabbit Foot (+1 Save, 25 Gold)',
        'Gilded Skeleton Key (40 Gold)',
        'Smoke Bomb Flask (20 Gold)',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_shaman_vael',
      name: 'Vael Earthcaller',
      role: 'Hermit Stone Shaman',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/tiefling.png',
      greeting: 'The bedrock hums with ancient memory. Listen closely, and the mountain itself will reveal its secrets.',
      dialogueOptions: [
        'Interpret the whispers in the stone.',
        'Grant our party your subterranean warding.',
      ],
      healPower: 22,
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_gnome_lumina',
      name: 'Lumina Gemshaper',
      role: 'Deep Gnome Jeweler',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/gnome.png',
      greeting: 'Greetings! I carve harmonic planar lenses out of raw cavern crystals. Would you like your weapons enchanted?',
      dialogueOptions: [
        'Show us your enchanted gemstones.',
        'Can you polish our party\'s arcane focuses?',
      ],
      shopItems: [
        'Azurite Crystal of Mana (+5 Max HP, 65 Gold)',
        'Glowstone Amulet (Darkvision, 50 Gold)',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_sentry_varis',
      name: 'Sentry Varis',
      role: 'Subterranean Scout',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/elf.png',
      greeting: 'The dark beneath the world has eyes everywhere. Stay near the torchlight and keep your shields up.',
      dialogueOptions: [
        'What dangers lurk in the deeper fissures?',
        'Join our vanguard for the delve ahead.',
      ],
      canRecruit: true,
    ),
  ];

  for (final arch in archetypes) {
    Point? pos;
    for (int attempts = 0; attempts < 35; attempts++) {
      final room = cave.rooms[rng.nextInt(cave.rooms.length)];
      final tx = room.x + 1 + rng.nextInt(max(1, room.w - 2));
      final ty = room.y + 1 + rng.nextInt(max(1, room.h - 2));
      final k = '$tx,$ty';
      if (!taken.contains(k) && cave.tileAt(tx, ty).walkable) {
        pos = Point(tx, ty);
        taken.add(k);
        break;
      }
    }
    if (pos != null) {
      npcs.add(arch.copyWith(pos: pos));
    }
  }

  return npcs;
}

List<MapAnimal> generateCaveAnimals(DungeonMap cave, {Set<String> excluding = const {}}) {
  final animals = <MapAnimal>[];
  final rng = Random(cave.seed ^ 0x414E4943); // "ANIC"
  final taken = Set<String>.from(excluding);

  final archetypes = [
    ('bat', 'Echolocating Cave Bat', 'Leathery-winged bat clinging upside down from a limestone spire.', 'Squeee! The gentle cave bat flaps soft wings and tilts its head at your lantern.', 'cave_bat'),
    ('frog', 'Bioluminescent Cave Frog', 'Translucent glowing amphibian sitting near subterranean pools.', 'Ribbit-croak... A soft cyan glow pulsates gently from its speckled skin.', 'cave_frog'),
    ('beetle', 'Chasm Armor Beetle', 'Heavy carapaced burrower chewing through mineral veins.', 'Click-clack! The sturdy beetle taps its antennae harmlessly against your boots.', 'cave_beetle'),
    ('rat', 'Deep Scurrier Rat', 'Nimble subterranean rodent with exceptional low-light vision.', 'Snuffle... The cave rat nibbles a crumb from your hand with tiny paws.', 'cave_rat'),
    ('hound', 'Blind Cave Hound', 'Pale silky hound bred by deep dwellers for cavern guidance.', 'Whine... The loyal hound presses its cool muzzle into your palm lovingly.', 'cave_hound'),
  ];

  final count = 7 + rng.nextInt(4); // 7..10 animals
  for (int i = 0; i < count; i++) {
    final (species, name, flavor, dialogue, petId) = archetypes[i % archetypes.length];
    for (int attempts = 0; attempts < 35; attempts++) {
      final x = 3 + rng.nextInt(cave.width - 6);
      final y = 3 + rng.nextInt(cave.height - 6);
      final k = '$x,$y';
      if (!taken.contains(k) && cave.tileAt(x, y).walkable) {
        taken.add(k);
        animals.add(MapAnimal(
          id: 'cave_animal_${species}_$i',
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
