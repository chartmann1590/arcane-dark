import 'dart:math';
import '../../domain/map/tile_types.dart';
import 'tavern_populator.dart';

List<MapProp> generateVillageProps(DungeonMap village) {
  final props = <MapProp>[];
  final taken = <String>{};

  // 1. Central Town Square Stone Fountain / Well
  final townSquare = village.rooms.firstWhere((r) => r.id == 0, orElse: () => village.rooms.first);
  final centerFountain = Point(townSquare.centerX, townSquare.centerY);
  props.add(MapProp(
    pos: centerFountain,
    asset: 'assets/tiles/prop_fountain.png',
    isSolid: true,
    name: 'Oakhaven Stone Fountain',
    interactionText: 'A carved limestone fountain where pure mountain spring water spouts from an eagle’s beak. Refreshing and restorative.',
  ));
  taken.add('${centerFountain.x},${centerFountain.y}');

  // 2. Thematic Shop & Building Props for every building
  for (final room in village.rooms) {
    if (room.id == 0) continue;
    final center = Point(room.centerX, room.centerY);
    final key = '${center.x},${center.y}';
    if (taken.contains(key)) continue;

    switch (room.id) {
      case 1: // Blacksmith
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_brazier.png',
          isSolid: true,
          name: 'Blacksmith Anvil & Roaring Forge',
          interactionText: 'A heavy iron anvil resting beside glowing coke embers. The smith’s hammer rings true.',
        ));
        taken.add(key);
        break;

      case 2: // Apothecary
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_cauldron.png',
          isSolid: true,
          name: 'Apothecary Distillation Still',
          interactionText: 'A copper alembic still bubbling with aromatic essence of mountain sage and wild mint.',
        ));
        taken.add(key);
        break;

      case 3: // Tavern
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_bar_counter.png',
          isSolid: true,
          name: 'Polished Oak Tavern Bar',
          interactionText: 'Stacked kegs of golden cider and elderberry wine. Pewter tankards await thirsty patrons.',
        ));
        taken.add(key);
        break;

      case 4: // Town Hall
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_lectern.png',
          isSolid: true,
          name: 'Town Archive Lectern',
          interactionText: 'A heavy municipal ledger detailing realm charters, land deeds, and local trade treaties.',
        ));
        taken.add(key);
        break;

      case 5: // Gatehouse
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_weapon_rack.png',
          isSolid: true,
          name: 'Town Watch Halberd Rack',
          interactionText: 'Polished iron polearms, shields bearing the golden oak sigil, and spare crossbow bolts.',
        ));
        taken.add(key);
        break;

      case 6: // Bakery / Mill
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_crates.png',
          isSolid: true,
          name: 'Bakery Flour Sacks & Dough Table',
          interactionText: 'Wooden troughs filled with milled barley flour and loaves sprinkled with sesame.',
        ));
        taken.add(key);
        break;

      case 7: // Woodcutter / Guild
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_table.png',
          isSolid: true,
          name: 'Carpenter Bench & Timber Saws',
          interactionText: 'Honed adzes, planes, and fragrant blocks of freshly cut cedar and oak timber.',
        ));
        taken.add(key);
        break;

      case 8: // Weaver / Cottage
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_rug.png',
          isSolid: false,
          name: 'Woven Floral Carpet',
          interactionText: 'A richly dyed wool rug depicting golden falcons gliding over emerald meadows.',
        ));
        taken.add(key);
        break;

      case 9: // Homestead / Caravanserai
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_chair.png',
          isSolid: true,
          name: 'Hearth Rocking Chair & Table',
          interactionText: 'A cozy fireside chair beside a smoking pipe and a bowl of fresh orchard plums.',
        ));
        taken.add(key);
        break;
    }
  }

  // 3. Market Square Stalls & Bazaar Wares around central plaza
  final plazaOffsets = [
    (-2, -2), (2, -2), (-2, 2), (2, 2),
    (0, -3), (0, 3), (-3, 0), (3, 0),
  ];

  final marketProps = [
    ('assets/tiles/prop_market_stall.png', 'Market Produce Stall', 'Wooden crates piled high with crisp orchard apples, pumpkins, and herbs.'),
    ('assets/tiles/prop_barrel.png', 'Autumn Cider Casks', 'Tapped barrels of golden spiced cider fragrant with cinnamon and cloves.'),
    ('assets/tiles/prop_crates.png', 'Merchant Trade Crates', 'Imported bolts of velvet, ceramic spice jars, and silver trade trinkets.'),
    ('assets/tiles/prop_torch.png', 'Town Iron Streetlamp', 'A sturdy cast-iron streetlamp keeping the cobblestone avenues warmly illuminated.'),
    ('assets/tiles/prop_cart.png', 'Farmstead Hay Wagon', 'A sturdy wooden cart stacked with sweet-smelling mountain timothy hay.'),
    ('assets/tiles/prop_table.png', 'Jeweler Display Table', 'Wares on green velvet: copper rings, polished amber pendants, and cut river gems.'),
    ('assets/tiles/prop_shrine.png', 'Wayfarer Blessing Shrine', 'A modest stone shrine dedicated to safe journeys on the realm highways.'),
    ('assets/tiles/prop_torch.png', 'Square Lantern Post', 'Ornamental lantern beacon guiding travelers through the town square.'),
  ];

  for (int i = 0; i < plazaOffsets.length; i++) {
    final (dx, dy) = plazaOffsets[i];
    final p = Point(townSquare.centerX + dx, townSquare.centerY + dy);
    final k = '${p.x},${p.y}';
    if (!taken.contains(k) && p.x >= 1 && p.x < village.width - 1 && p.y >= 1 && p.y < village.height - 1) {
      final (asset, name, desc) = marketProps[i % marketProps.length];
      props.add(MapProp(
        pos: p,
        asset: asset,
        isSolid: !asset.contains('torch') && !asset.contains('rug'),
        name: name,
        interactionText: desc,
      ));
      taken.add(k);
    }
  }

  // 4. Street Lamps along thoroughfares
  final rng = Random(village.seed);
  for (int i = 0; i < 6; i++) {
    final lx = 4 + rng.nextInt(village.width - 8);
    final ly = 4 + rng.nextInt(village.height - 8);
    final k = '$lx,$ly';
    if (!taken.contains(k) && village.tileAt(lx, ly) == TileType.floor) {
      props.add(MapProp(
        pos: Point(lx, ly),
        asset: 'assets/tiles/prop_torch.png',
        isSolid: false,
        name: 'Village Lamppost',
        interactionText: 'A warm streetlamp warding the road against night shadows.',
      ));
      taken.add(k);
    }
  }

  return props;
}

List<MapNpc> generateVillageNpcs(DungeonMap village, {Set<String> excluding = const {}}) {
  final npcs = <MapNpc>[];
  final rng = Random(village.seed ^ 0x564E5043); // "VNPC"
  final taken = Set<String>.from(excluding);

  final archetypes = [
    MapNpc(
      id: 'npc_mayor_jonathan',
      name: 'Mayor Jonathan',
      role: 'Village Magistrate',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'Welcome to Oakhaven, esteemed travelers! Our gates are ever open to honorable adventurers.',
      dialogueOptions: [
        'What rumors or bounties are posted in town?',
        'Tell me about the history of Oakhaven.',
        'Where can we purchase supplies for the road?',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_blacksmith_torvald',
      name: 'Torvald Ironbreaker',
      role: 'Master Weaponsmith',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/dwarf.png',
      greeting: 'Need your blade sharpened or your armor plates mended? You won’t find finer dwarven steel in the province!',
      dialogueOptions: [
        'Can you upgrade our party’s weaponry?',
        'What forged weapons do you have in stock?',
        'Do you need any rare ores from the caverns?',
      ],
      shopItems: [
        'Tempered Broadsword (45 Gold)',
        'Reinforced Iron Shield (30 Gold)',
        'Chain Shirt Armor (75 Gold)',
        'Masterwork Whetstone (10 Gold)',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_alchemist_sylph',
      name: 'Sylph Whisperwind',
      role: 'Herbal Alchemist',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/elf.png',
      greeting: 'Blessings of flora upon you. My tinctures cure all manner of venom, fatigue, and wound.',
      dialogueOptions: [
        'Show me your healing potions and draughts.',
        'Can you brew a potion of resistance?',
        'What strange plants grow in the nearby forest?',
      ],
      shopItems: [
        'Potion of Healing (25 Gold)',
        'Elixir of Clarity (35 Gold)',
        'Antitoxin Flask (20 Gold)',
        'Vial of Faerie Fire (40 Gold)',
      ],
      healPower: 20,
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_captain_valerie',
      name: 'Captain Valerie',
      role: 'Town Watch Commander',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'Keep the peace in our streets and we’ll have no trouble. If you’re looking for work, the perimeter needs guarding.',
      dialogueOptions: [
        'Are there any bandit threats near the borders?',
        'Can you share tactical advice for crypt delving?',
        'How can our party aid the town garrison?',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_bard_lyra',
      name: 'Lyra Stringweaver',
      role: 'Wandering Troubadour',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/halfling.png',
      greeting: 'A song for a copper, a grand saga for a flagon of cider! Have you heard the ballad of the Clockwork Vault?',
      dialogueOptions: [
        'Sing us a ballad of heroes!',
        'What secrets have you overheard in your travels?',
        'Can you inspire our party with a tale?',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_miller_gwen',
      name: 'Gwen Miller',
      role: 'Town Baker & Merchant',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'Warm honey loaves fresh from the stone oven! Eat well before you set out onto the perilous roads.',
      dialogueOptions: [
        'We’d like to buy journey rations.',
        'What is the mood of the townspeople today?',
      ],
      shopItems: [
        'Honey Oat Loaf (3 Gold)',
        'Traveler’s Trail Rations (5 Gold)',
        'Goat Milk Cheese Wheel (4 Gold)',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_urchin_toby',
      name: 'Toby Swiftfoot',
      role: 'Town Urchin & Scout',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/halfling.png',
      greeting: 'Psst! Want to know the safest shortcut through the Whispering Woods? Won\'t cost ya more than a silver coin!',
      dialogueOptions: [
        'Here’s a silver piece. What’s the secret route?',
        'Stay out of danger, little one.',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_scholar_alden',
      name: 'Master Alden',
      role: 'Arcane Scholar & Antiquarian',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/gnome.png',
      greeting: 'Greetings, seeker of arcane mysteries! I study the ley line resonances crossing through our township.',
      dialogueOptions: [
        'Do you have spell scrolls for sale?',
        'What ancient lore can you decipher for us?',
      ],
      shopItems: [
        'Scroll of Identify (40 Gold)',
        'Scroll of Mage Armor (50 Gold)',
        'Potion of Mind Shielding (60 Gold)',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_farmer_barnaby',
      name: 'Barnaby Greenhollow',
      role: 'Pasture Farmer',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/halfling.png',
      greeting: 'Fine weather for the harvest! If you\'re heading out past the south orchard, keep an ear out for prowling wolves.',
      dialogueOptions: [
        'Have wolves been troubling your herd?',
        'Can you spare fresh fruit for our travel pack?',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_clothier_sarah',
      name: 'Sarah Silverstitch',
      role: 'Master Weaver & Clothier',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'Warm wool cloaks and weather-waxed traveler capes! A cold night on the road will freeze unprepared wanderers.',
      dialogueOptions: [
        'Show me your winter cloaks and gear.',
        'Can you mend torn leather armor?',
      ],
      shopItems: [
        'Weather-Waxed Traveler Cloak (15 Gold)',
        'Embroidered Silk Sash (25 Gold)',
        'Reinforced Leather Bracers (35 Gold)',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_priest_donald',
      name: 'Brother Donald',
      role: 'Sun Temple Priest',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'May the radiant dawn preserve your fellowship. Receive a sacred blessing before facing the darkness.',
      dialogueOptions: [
        'We seek a blessing for our journey.',
        'Can you mend our wounded companions?',
      ],
      healPower: 25,
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_veteran_kaelen',
      name: 'Sergeant Kaelen',
      role: 'Veteran Gatekeeper',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/dwarf.png',
      greeting: 'Halt, travelers! Road to the capital is rife with goblin ambushes. Keep your blades loose in their scabbards.',
      dialogueOptions: [
        'We can assist with patrol duties.',
        'Would you join our company as vanguard?',
      ],
      canRecruit: true,
    ),
  ];

  for (int i = 0; i < archetypes.length; i++) {
    final arch = archetypes[i];
    final room = (i < village.rooms.length) ? village.rooms[i] : village.rooms[rng.nextInt(village.rooms.length)];

    Point? pos;
    for (int attempts = 0; attempts < 35; attempts++) {
      final tx = room.x + 1 + rng.nextInt(max(1, room.w - 2));
      final ty = room.y + 1 + rng.nextInt(max(1, room.h - 2));
      final k = '$tx,$ty';
      if (!taken.contains(k) && village.tileAt(tx, ty).walkable) {
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

List<MapAnimal> generateVillageAnimals(DungeonMap village, {Set<String> excluding = const {}}) {
  final animals = <MapAnimal>[];
  final rng = Random(village.seed ^ 0x56414E49); // "VANI"
  final taken = Set<String>.from(excluding);

  final archetypes = [
    ('hound', 'Town Guard Mastiff', 'Faithful watchdog patrolling the village avenues.', 'Woof! The mastiff wags its tail and leans gently against your leg.', 'village_hound'),
    ('cat', 'Alley Tabby Cat', 'Sleek mouser stalking sunbeams near the merchant stalls.', 'Purr... The tabby cat rubs affectionately against your greaves.', 'village_cat'),
    ('bird', 'Marketplace Dove', 'Pure white dove resting on shop awnings and town square.', 'Coo-coo! The dove flutters down and perches calmly nearby.', 'village_bird'),
    ('horse', 'Stall Draft Horse', 'Sturdy draft horse tied near the blacksmith forge.', 'Neigh! The horse snorts warmly and accepts a friendly pat.', 'village_horse'),
    ('cow', 'Pasture Dairy Cow', 'Gentle brown cow grazing quietly near town borders.', 'Moo... The cow blinks slowly and munches peacefully on clover.', 'village_cow'),
    ('rat', 'Cellar Whisker Rat', 'Quick-witted little rat foraging crumbs behind the bakery.', 'Squeak! The tiny rat pauses, wiggling its whiskers curiously.', 'village_rat'),
    ('dog', 'Shepherd Collie', 'Eager herding dog keeping sheep safely inside the fences.', 'Arf-arf! The collie circles you happily and panting.', 'village_shepherd'),
    ('cat', 'Hearth Calico Cat', 'Plump sleeping cat curled up beside the tavern stone steps.', 'Mew... It stretches its paws contentedly.', 'village_calico'),
  ];

  final count = 8 + rng.nextInt(4); // 8..11 animals
  for (int i = 0; i < count; i++) {
    final (species, name, flavor, dialogue, petId) = archetypes[i % archetypes.length];
    for (int attempts = 0; attempts < 35; attempts++) {
      final x = 3 + rng.nextInt(village.width - 6);
      final y = 3 + rng.nextInt(village.height - 6);
      final k = '$x,$y';
      if (!taken.contains(k) && village.tileAt(x, y).walkable) {
        taken.add(k);
        animals.add(MapAnimal(
          id: 'village_animal_${species}_$i',
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
