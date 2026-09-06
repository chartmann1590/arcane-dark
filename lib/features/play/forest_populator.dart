import 'dart:math';
import '../../domain/map/tile_types.dart';
import 'tavern_populator.dart';

List<MapProp> generateForestProps(DungeonMap forest) {
  final props = <MapProp>[];
  final rng = Random(forest.seed ^ 0x464F5245); // "FORE"
  final taken = <String>{};

  for (final room in forest.rooms) {
    final center = Point(room.centerX, room.centerY);
    final key = '${center.x},${center.y}';
    if (taken.contains(key)) continue;

    switch (room.id) {
      case 0: // Trailhead
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_campfire.png',
          isSolid: false,
          name: 'Wayfarer Campfire',
          interactionText: 'A welcoming campfire crackles with pine needles. Resting here restores weary spirits.',
        ));
        taken.add(key);
        break;

      case 1: // Druid Grove
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_altar.png',
          isSolid: true,
          name: 'Verdant Moon Altar',
          interactionText: 'An ancient granite obelisk inscribed with druidic spiral runes. A gentle divine warmth radiates through your palms.',
        ));
        taken.add(key);
        break;

      case 2: // Hermit Camp
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_cauldron.png',
          isSolid: true,
          name: 'Herbalist Brewpot',
          interactionText: 'A cast-iron pot simmering with aromatic mountain mint and elderflower.',
        ));
        taken.add(key);
        break;

      case 3: // Timber Yard
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_crates.png',
          isSolid: true,
          name: 'Harvested Pine Timber',
          interactionText: 'Neatly bundled stacks of seasoned firewood and aromatic cedar resin.',
        ));
        taken.add(key);
        break;

      case 4: // Sunken Brook
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_chest.png',
          isSolid: true,
          name: 'Moss-Covered Cache',
          interactionText: 'A water-sealed chest tucked beneath the roots of an ancient willow.',
        ));
        taken.add(key);
        break;

      case 5: // Wolf Crag
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_statue.png',
          isSolid: true,
          name: 'Guardian Totem of the Wilds',
          interactionText: 'A weather-worn stone carving of a soaring raptor, overlooking the forest canopy below.',
        ));
        taken.add(key);
        break;
    }
  }

  // Scattered forest ambiance (moss, boulders, logs)
  final candidateTiles = <Point>[];
  for (int y = 2; y < forest.height - 2; y++) {
    for (int x = 2; x < forest.width - 2; x++) {
      if (forest.tileAt(x, y) == TileType.plains || forest.tileAt(x, y) == TileType.floor) {
        final k = '$x,$y';
        if (!taken.contains(k) && !(x == forest.entryPoint.x && y == forest.entryPoint.y)) {
          candidateTiles.add(Point(x, y));
        }
      }
    }
  }
  candidateTiles.shuffle(rng);

  final forestAssets = [
    'assets/tiles/prop_moss.png',
    'assets/tiles/prop_rubble.png',
    'assets/tiles/prop_campfire.png',
    'assets/tiles/prop_crates.png',
  ];

  for (final p in candidateTiles.take(8)) {
    final asset = forestAssets[rng.nextInt(forestAssets.length)];
    props.add(MapProp(
      pos: p,
      asset: asset,
      isSolid: asset.contains('crates'),
      name: asset.contains('moss') ? 'Wild Fern & Moss' : (asset.contains('campfire') ? 'Abandoned Fire Pit' : 'Forest Boulder'),
      interactionText: 'Natural woodland scenery undisturbed by civilization.',
    ));
    taken.add('${p.x},${p.y}');
  }

  return props;
}

List<MapNpc> generateForestNpcs(DungeonMap forest, {Set<String> excluding = const {}}) {
  final npcs = <MapNpc>[];
  final rng = Random(forest.seed ^ 0x4E504346); // "NPCF"
  final taken = Set<String>.from(excluding);

  final archetypes = [
    MapNpc(
      id: 'npc_ranger_katherine',
      name: 'Ranger Katherine',
      role: 'Woodland Scout',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/elf.png',
      greeting: 'Halt, travelers! Tread lightly upon these trails. The canopy listens to every footstep.',
      dialogueOptions: [
        'What creatures roam this forest?',
        'Have you seen any ancient ruins nearby?',
        'Can you share tips for surviving in the wild?',
      ],
      healPower: 8,
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_druid_oakenshade',
      name: 'Druid Oakenshade',
      role: 'Circle of the Grove',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'Nature’s grace be upon your path. The Leylines flow strong beneath the mossy stones.',
      dialogueOptions: [
        'Teach me about the ancient stones.',
        'May I receive your blessing?',
        'I seek knowledge of the forest spirits.',
      ],
      healPower: 15,
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_woodcutter_brant',
      name: 'Brant the Woodcutter',
      role: 'Timber Forester',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/dwarf.png',
      greeting: 'Ho there! Good to see friendly faces out in the timber. Keep an eye out for timber wolves near the crags!',
      dialogueOptions: [
        'Are there wolves nearby?',
        'Where does this river lead?',
        'Do you need help hauling lumber?',
      ],
      healPower: 0,
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_traveling_merchant',
      name: 'Volo the Peddler',
      role: 'Wandering Caravan Merchant',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/halfling.png',
      greeting: 'Greetings, fellow wayfarer! Fresh supplies straight from the capital markets!',
      dialogueOptions: [
        'What goods do you have for sale?',
        'Any news from the neighboring settlements?',
        'Do you trade for rare forest herbs?',
      ],
      shopItems: [
        'Healing Salve (15 Gold)',
        'Antitoxin Vial (25 Gold)',
        'Traveler’s Cloak of Warmth (40 Gold)',
        'Rations Pack (5 Gold)',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_hermit_alistair',
      name: 'Old Alistair',
      role: 'Forest Hermit & Herbalist',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/gnome.png',
      greeting: 'Hehehe, few wander so deep into the willows! Sit by the fire, let the kettle brew.',
      dialogueOptions: [
        'What herb remedies do you brew?',
        'Tell me the history of this woods.',
        'Can you teach me herb gathering?',
      ],
      healPower: 12,
      canRecruit: false,
    ),
  ];

  for (final arch in archetypes) {
    // Pick walkable room or path
    Point? pos;
    for (int attempts = 0; attempts < 30; attempts++) {
      final room = forest.rooms[rng.nextInt(forest.rooms.length)];
      final tx = room.x + 1 + rng.nextInt(max(1, room.w - 2));
      final ty = room.y + 1 + rng.nextInt(max(1, room.h - 2));
      final k = '$tx,$ty';
      if (!taken.contains(k) && forest.tileAt(tx, ty).walkable) {
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

List<MapAnimal> generateForestAnimals(DungeonMap forest, {Set<String> excluding = const {}}) {
  final animals = <MapAnimal>[];
  final rng = Random(forest.seed ^ 0x46414E49); // "FANI"
  final taken = Set<String>.from(excluding);

  final archetypes = [
    ('deer', 'White-tailed Stag', 'Graceful antlered stag stepping lightly through pine needles.', 'The stag bows its crowned head calmly, accepting your peaceful presence.', 'forest_stag'),
    ('wolf', 'Grey Timber Wolf', 'Lean grey wolf padding quietly along the forest brush.', 'A soft whimper echoes as the wolf nudges your arm with guarded curiosity.', 'forest_wolf'),
    ('owl', 'Tawny Great Horned Owl', 'Vigilant night bird perched on mossy timber branches.', 'Hoo-hoo! Amber eyes blink serenely as feathers rustle in the breeze.', 'forest_owl'),
    ('fox', 'Russet Red Fox', 'Playful orange fox darting between berry bushes.', 'Yip! The swift fox curls around your boots with bushy tail raised high.', 'forest_fox'),
    ('bear', 'Timberland Black Bear', 'Curious yearling bear foraging for honey and blackberries.', 'Grr-ruff... The bear sits back on its haunches and sniffs your provisions friendly.', 'forest_bear'),
    ('frog', 'Riverbank Bullfrog', 'Vibrant green tree frog basking on warm moss rocks.', 'Ribbit! The sleek amphibian blinks peacefully by the water spray.', 'forest_frog'),
    ('beetle', 'Emerald Jewel Beetle', 'Iridescent metallic beetle crawling across fallen logs.', 'A shimmering green carapace reflects dappled canopy sunlight.', 'forest_beetle'),
    ('hound', 'Forest Tracker Hound', 'Hardy hunting dog roaming ancient deer trails.', 'Woof-woof! A joyful bark rings out as the hound bounds around you.', 'forest_hound'),
  ];

  final count = 5 + rng.nextInt(4); // 5..8 animals
  for (int i = 0; i < count; i++) {
    final (species, name, flavor, dialogue, petId) = archetypes[i % archetypes.length];
    for (int attempts = 0; attempts < 30; attempts++) {
      final x = 2 + rng.nextInt(forest.width - 4);
      final y = 2 + rng.nextInt(forest.height - 4);
      final k = '$x,$y';
      if (!taken.contains(k) && forest.tileAt(x, y).walkable) {
        taken.add(k);
        animals.add(MapAnimal(
          id: 'forest_animal_${species}_$i',
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
