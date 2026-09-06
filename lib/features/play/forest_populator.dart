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

      case 6: // Fairy Glade
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_shrine.png',
          isSolid: false,
          name: 'Fairy Ring Mushroom Shrine',
          interactionText: 'A circle of glowing mushrooms whispering faint playful chimes in the woodland breeze.',
        ));
        taken.add(key);
        break;
    }
  }

  // Scattered forest ambiance (campfires, logs, crystals, rubble)
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
    ('assets/tiles/prop_campfire.png', 'Forest Trail Hearth', 'A small stone ring with glowing embers left by elven rangers.'),
    ('assets/tiles/prop_crates.png', 'Forester Supply Cache', 'Waterproof timber crates containing dried venison and rope.'),
    ('assets/tiles/prop_crystals.png', 'Wild Earth Geode', 'An earth crystal cluster jutting from mossy loam, shimmering with nature mana.'),
    ('assets/tiles/prop_table.png', 'Fletcher Workbench', 'A flat log used for carving ash longbows and feathering arrows.'),
    ('assets/tiles/prop_shrine.png', 'Mossy Wayshrine', 'A weathered stone shrine to the Green Lord, draped in blossoming ivy.'),
  ];

  for (final p in candidateTiles.take(10)) {
    final (asset, name, desc) = forestAssets[rng.nextInt(forestAssets.length)];
    props.add(MapProp(
      pos: p,
      asset: asset,
      isSolid: asset.contains('crates') || asset.contains('crystals'),
      name: name,
      interactionText: desc,
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
      name: 'Captain Danica',
      role: 'Woodland Ranger Captain',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/elf.png',
      greeting: 'Halt, travelers! Tread lightly upon these ancient trails. The canopy listens to every footstep.',
      dialogueOptions: [
        'What predators roam this woodland?',
        'Have you spotted ancient elven ruins?',
        'Would you join our company as ranger guide?',
      ],
      healPower: 10,
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_druid_oakenshade',
      name: 'Archdruid Oakenshade',
      role: 'Circle of the Grove',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'Nature’s grace be upon your path. The Leylines flow strong beneath the mossy roots.',
      dialogueOptions: [
        'Teach me the secrets of the ancient stones.',
        'May our party receive your sacred blessing?',
        'What dark corruptions threaten the forest?',
      ],
      healPower: 20,
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
        'Show me your forest salves and reagents.',
        'Tell me the legends of the whispering canopy.',
        'Can you brew an elixir of woodland stealth?',
      ],
      shopItems: [
        'Elixir of Woodland Camouflage (30 Gold)',
        'Herbal Poultice of Healing (20 Gold)',
        'Tincture of Night Vision (35 Gold)',
      ],
      healPower: 15,
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_woodcutter_brant',
      name: 'Brant the Woodcutter',
      role: 'Master Forester',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/dwarf.png',
      greeting: 'Ho there! Good to see friendly faces in the timber. Watch for grey wolves near the crags!',
      dialogueOptions: [
        'Where can we purchase sturdy camping timber?',
        'Can you repair our wooden shields and shafts?',
      ],
      shopItems: [
        'Ash Wood Tower Shield (40 Gold)',
        'Hone-Forged Woodman Axe (35 Gold)',
        'Bundle of Hardwood Torches (5 Gold)',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_traveling_merchant',
      name: 'Volo the Peddler',
      role: 'Wandering Caravan Merchant',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/halfling.png',
      greeting: 'Greetings, fellow wayfarer! Fresh supplies and exotic curios straight from the capital markets!',
      dialogueOptions: [
        'Show me your caravan wares.',
        'Any news from the neighboring cities?',
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
      id: 'npc_fletcher_kira',
      name: 'Kira Bowstring',
      role: 'Elven Fletcher & Archer',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/elf.png',
      greeting: 'Every arrow I fletch carries the blessing of the wind. Need your quiver restocked?',
      dialogueOptions: [
        'Show me your custom fletched arrows.',
        'Can you teach me marksmanship fundamentals?',
      ],
      shopItems: [
        'Quiver of Silvered Arrows (35 Gold)',
        'Yew Composite Longbow (65 Gold)',
        'Hawk-Feather Hunting Dagger (25 Gold)',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_trapper_olg',
      name: 'Trapper Olg',
      role: 'Wilderness Trapper',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/orc.png',
      greeting: 'Olg knows every burrow and deer trail. Respect the wild beasts and they respect you.',
      dialogueOptions: [
        'What animal pelts do you have in stock?',
        'Have you tracked any dangerous monsters nearby?',
      ],
      shopItems: [
        'Warm Wolf-Fur Mantle (30 Gold)',
        'Steel-Toothed Snare Trap (15 Gold)',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_bard_sylas',
      name: 'Sylas Whisperbark',
      role: 'Wandering Nature Bard',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'The leaves whisper verses of ancient forgotten kingdoms. Listen closely to the wind!',
      dialogueOptions: [
        'Play a melody of woodland tranquility.',
        'What secrets sleep under these roots?',
      ],
      healPower: 12,
      canRecruit: true,
    ),
  ];

  for (final arch in archetypes) {
    Point? pos;
    for (int attempts = 0; attempts < 35; attempts++) {
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

  final count = 8 + rng.nextInt(4); // 8..11 animals
  for (int i = 0; i < count; i++) {
    final (species, name, flavor, dialogue, petId) = archetypes[i % archetypes.length];
    for (int attempts = 0; attempts < 35; attempts++) {
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
