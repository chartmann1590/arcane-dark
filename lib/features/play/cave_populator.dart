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
      case 0: // Cavern Mouth
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_torch.png',
          isSolid: false,
          name: 'Prospector’s Wall Sconce',
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

      case 2: // Sunken Lake
        props.add(MapProp(
          pos: Point(room.x + 2, room.y + 2),
          asset: 'assets/tiles/prop_moss.png',
          isSolid: false,
          name: 'Bioluminescent Shoreline Flora',
          interactionText: 'Glowing turquoise cave moss growing on subterranean riverbanks, illuminating the dark waters.',
        ));
        taken.add('${room.x + 2},${room.y + 2}');
        break;

      case 3: // Mine Excavation
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_crates.png',
          isSolid: true,
          name: 'Dwarven Ore Cart & Pickaxes',
          interactionText: 'A wooden rail cart laden with raw silver ore and discarded iron excavation tools.',
        ));
        taken.add(key);
        break;

      case 4: // Chasm Crossing
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_pillar.png',
          isSolid: true,
          name: 'Ancient Limestone Stalagmite',
          interactionText: 'A towering limestone pillar formed over millennia of steady mineral seepage.',
        ));
        taken.add(key);
        break;

      case 5: // Ancient Sanctum
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

  // Scattered cave ambiance: stalagmites, glowing crystals, rubble, bones
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
    'assets/tiles/prop_crystals.png',
    'assets/tiles/prop_rubble.png',
    'assets/tiles/prop_bones.png',
    'assets/tiles/prop_moss.png',
    'assets/tiles/prop_chest.png',
  ];

  for (final p in candidateTiles.take(9)) {
    final asset = caveAssets[rng.nextInt(caveAssets.length)];
    props.add(MapProp(
      pos: p,
      asset: asset,
      isSolid: asset.contains('crystals') || asset.contains('chest'),
      name: asset.contains('crystals') ? 'Luminescent Crystal Shard' : (asset.contains('chest') ? 'Sunken Prospector Coffer' : 'Cavern Rubble'),
      interactionText: 'Subterranean geological remnants buried deep beneath the mountains.',
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
      greeting: 'Watch yer step, friend! The lower strata are unstable, but by the gods, the mythril veins here run pure!',
      dialogueOptions: [
        'Have you found any rare minerals or gems?',
        'Which tunnels lead deeper down?',
        'Do you need assistance defending the claim?',
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
        'Are there safe resting alcoves nearby?',
      ],
      healPower: 10,
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_goblin_snik',
      name: 'Snik the Turncoat',
      role: 'Goblin Cave Guide',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/halfling.png',
      greeting: 'Don’t smash Snik! Snik knows all secret crawlspaces! You got shiny coins for good cave directions, yes?',
      dialogueOptions: [
        'Here’s 5 gold. Show me the secret bypass.',
        'Where do the hostile monsters nest?',
        'Will you scout the darkness ahead for us?',
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
      healPower: 18,
      canRecruit: false,
    ),
  ];

  for (final arch in archetypes) {
    Point? pos;
    for (int attempts = 0; attempts < 30; attempts++) {
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

  final count = 5 + rng.nextInt(4); // 5..8 animals
  for (int i = 0; i < count; i++) {
    final (species, name, flavor, dialogue, petId) = archetypes[i % archetypes.length];
    for (int attempts = 0; attempts < 30; attempts++) {
      final x = 2 + rng.nextInt(cave.width - 4);
      final y = 2 + rng.nextInt(cave.height - 4);
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
