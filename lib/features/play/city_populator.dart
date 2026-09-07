import 'dart:math';
import '../../domain/map/tile_types.dart';
import 'tavern_populator.dart';

List<MapProp> generateCityProps(DungeonMap city) {
  final props = <MapProp>[];
  final taken = <String>{};

  final bazaar = city.rooms.firstWhere((r) => r.id == 0, orElse: () => city.rooms.first);

  // 1. Central Bazaar Market Stalls & City Centerpiece
  final centerFountain = Point(bazaar.centerX, bazaar.centerY);
  props.add(MapProp(
    pos: centerFountain,
    asset: 'assets/tiles/prop_fountain.png',
    isSolid: true,
    name: 'Imperial Sun Monument & Basin',
    interactionText: 'A towering gilded sunburst statue spouting fresh water into a polished marble pool where travelers toss silver coins.',
  ));
  taken.add('${centerFountain.x},${centerFountain.y}');

  // Market Stalls in Bazaar corners
  final stallOffsets = [
    Point(bazaar.centerX - 3, bazaar.centerY - 2),
    Point(bazaar.centerX + 3, bazaar.centerY - 2),
    Point(bazaar.centerX - 2, bazaar.centerY + 3),
    Point(bazaar.centerX + 2, bazaar.centerY + 3),
    Point(bazaar.centerX - 4, bazaar.centerY),
    Point(bazaar.centerX + 4, bazaar.centerY),
  ];
  final stallNames = [
    'Silk & Spice Bazaar Stall',
    'Enchanted Curios & Relics Cart',
    'Master Armorer\'s Display Stall',
    'Apothecary & Herbalist Canopy',
    'Fine Gems & Jewelry Pavilion',
    'Caravan Provisions & Rations Stand',
  ];
  for (int i = 0; i < stallOffsets.length; i++) {
    final pt = stallOffsets[i];
    final key = '${pt.x},${pt.y}';
    if (!taken.contains(key) && pt.x >= 0 && pt.x < city.width && pt.y >= 0 && pt.y < city.height && city.tileAt(pt.x, pt.y).walkable) {
      props.add(MapProp(
        pos: pt,
        asset: 'assets/tiles/prop_market_stall.png',
        isSolid: true,
        name: stallNames[i % stallNames.length],
        interactionText: 'A bustling timber stall adorned with striped canvas, showcasing exotic goods from across the world.',
      ));
      taken.add(key);
    }
  }

  // 2. Thematic District Props
  for (final room in city.rooms) {
    if (room.id == 0) continue;
    final center = Point(room.centerX, room.centerY);
    final key = '${center.x},${center.y}';
    if (taken.contains(key)) continue;

    switch (room.id) {
      case 1: // High Citadel & Governor
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_throne.png',
          isSolid: true,
          name: 'Governor\'s Gilded Seat of Law',
          interactionText: 'An elevated velvet throne backed by the golden seal of the High Imperial Council.',
        ));
        taken.add(key);
        break;

      case 2: // Grand Cathedral
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_shrine.png',
          isSolid: true,
          name: 'High Radiant Altar of the Sun',
          interactionText: 'A massive sunstone dais glowing with warm divine luminescence. Holy blessings wash over all who pray.',
        ));
        taken.add(key);
        break;

      case 3: // Watch Barracks
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_weapon_rack.png',
          isSolid: true,
          name: 'Garrison Armory Weapon Rack',
          interactionText: 'Rows of polished steel halberds, heavy tower shields, and crossbow quivers.',
        ));
        taken.add(key);
        break;

      case 4: // Harbor Guild / Athenaeum
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_chest_gilded.png',
          isSolid: true,
          name: 'Imperial Trade Guild Vault',
          interactionText: 'Reinforced iron strongbox holding overseas trade manifestos and bags of silver coin.',
        ));
        taken.add(key);
        break;

      case 5: // Docks or Gatehouse
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_cart.png',
          isSolid: true,
          name: 'Harbor Freight Wagon',
          interactionText: 'A heavy transport wagon loaded with crates of salt fish, olive oil, and wine amphorae.',
        ));
        taken.add(key);
        break;

      case 6: // Academy / Gatehouse
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_crystals.png',
          isSolid: true,
          name: 'Artificer Arcane Conduit',
          interactionText: 'A crystal resonator channeling raw arcane force for municipal enchanting.',
        ));
        taken.add(key);
        break;
    }
  }

  // 3. Boulevard Streetlamps & Ornamental Urns
  final rng = Random(city.seed);
  for (int i = 0; i < 12; i++) {
    final lx = 3 + rng.nextInt(city.width - 6);
    final ly = 3 + rng.nextInt(city.height - 6);
    final k = '$lx,$ly';
    if (!taken.contains(k) && city.tileAt(lx, ly) == TileType.floor) {
      props.add(MapProp(
        pos: Point(lx, ly),
        asset: 'assets/tiles/prop_streetlamp.png',
        isSolid: false,
        name: 'Metropolitan Streetlamp',
        interactionText: 'A tall ornamental bronze lamppost illuminating the grand avenues.',
      ));
      taken.add(k);
    }
  }

  // 4. Promenade Flowerbeds & Planters
  for (int i = 0; i < 6; i++) {
    final fx = 4 + rng.nextInt(city.width - 8);
    final fy = 4 + rng.nextInt(city.height - 8);
    final k = '$fx,$fy';
    if (!taken.contains(k) && city.tileAt(fx, fy) == TileType.floor) {
      props.add(MapProp(
        pos: Point(fx, fy),
        asset: 'assets/tiles/prop_flowerbed.png',
        isSolid: false,
        name: 'Promenade Marble Planter',
        interactionText: 'Manicured royal lilies and purple petunias blooming in a sculpted marble planter.',
      ));
      taken.add(k);
    }
  }

  return props;
}

List<MapNpc> generateCityNpcs(DungeonMap city, {Set<String> excluding = const {}}) {
  final npcs = <MapNpc>[];
  final rng = Random(city.seed ^ 0x43495459); // "CITY"
  final taken = Set<String>.from(excluding);

  final archetypes = [
    MapNpc(
      id: 'npc_governor_aurelius',
      name: 'Governor Aurelius',
      role: 'City Magistrate & Governor',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'Greetings, citizens and honored wanderers. The High Citadel maintains order and justice across all seven districts.',
      dialogueOptions: [
        'What civic matters require heroic assistance?',
        'We seek the Council’s blessing for travel.',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_high_priestess_selene',
      name: 'High Priestess Selene',
      role: 'Sun Cathedral Luminary',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/elf.png',
      greeting: 'May the warmth of the solar dawn illuminate your heart and banish the deep shadows.',
      dialogueOptions: [
        'We request your sacred healing for our wounded.',
        'Tell us of the ancient prophecies.',
      ],
      healPower: 30,
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_captain_darius',
      name: 'Captain Darius',
      role: 'City Watch High Commander',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'Steel and vigil! Our guards patrol the avenues day and night. Keep the peace and you have our sword.',
      dialogueOptions: [
        'Are there rebel or criminal factions operating here?',
        'Would you accompany our party as tactical vanguard?',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_merchant_cassian',
      name: 'Prince Cassian',
      role: 'Grand Bazaar Merchant Prince',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/tiefling.png',
      greeting: 'Ah, travelers with keen eyes and heavy purses! I trade in wonders from lands beyond the great oceans.',
      dialogueOptions: [
        'Show us your most exotic artifacts and rings.',
        'What are the prevailing trade rumors in the city?',
      ],
      shopItems: [
        'Ring of the Desert Falcon (+2 DEX, 90 Gold)',
        'Vial of Phoenix Ash (Greater Healing, 60 Gold)',
        'Cloak of Gilded Protection (+1 AC, 110 Gold)',
        'Caravan Master Map of the Realm (25 Gold)',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_artificer_bram',
      name: 'Master Artificer Bram',
      role: 'Gnomish Automaton Engineer',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/gnome.png',
      greeting: 'Click-whir! Mind your fingers near the gear-presses. Looking for clockwork munitions or enchanted gadgets?',
      dialogueOptions: [
        'What wondrous mechanical devices do you sell?',
        'Can you reinforce our party\'s technological tools?',
      ],
      shopItems: [
        'Clockwork Decoy Trap (40 Gold)',
        'Arcane Shock Grenade (3d6 Lightning, 50 Gold)',
        'Masterwork Lockpick Set (+2 Sleight of Hand, 35 Gold)',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_guildmaster_fiona',
      name: 'Guildmaster Fiona',
      role: 'Harbor Guild Warden',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/dwarf.png',
      greeting: 'Cargo in, cargo out! If you\'ve arrived by canal skiff, mind the mooring ropes and pay your tariffs.',
      dialogueOptions: [
        'Any overseas shipping vessels hiring guards?',
        'Can we buy nautical provisions?',
      ],
      shopItems: [
        'Preserved Deep-Sea Rations (10 Gold)',
        'Mariner’s Waterproof Pouch (15 Gold)',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_urchin_pip',
      name: 'Pip the Shadow',
      role: 'Rooftop Courier & Rogue',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/halfling.png',
      greeting: 'Hey! You walk loud for someone exploring the canal districts. Drop a shiny coin and I’ll tell you who’s watching you.',
      dialogueOptions: [
        'Here’s two silver coins. Who’s following us?',
        'Keep your eyes open, Pip.',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_knight_lucian',
      name: 'Sir Lucian of the Sun',
      role: 'Knight Errant & Champion',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'My lance is pledged to honor and the defense of the defenseless. Where lies our next quest for justice?',
      dialogueOptions: [
        'Ride with us to cleanse the dark dungeons of the realm!',
        'What chivalric code guides your sword?',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_jeweler_cassandra',
      name: 'Lady Cassandra',
      role: 'Guild Jeweler & Gemologist',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/elf.png',
      greeting: 'Diamonds of the deep earth and radiant moonstones. Only the purest gems grace my velvet cases.',
      dialogueOptions: [
        'Can you appraise these gemstones for us?',
        'Do you sell enchanted rings of warding?',
      ],
      shopItems: [
        'Ring of Silver Shielding (50 Gold)',
        'Amulet of Health (80 Gold)',
      ],
      canRecruit: false,
    ),
    MapNpc(
      id: 'npc_artificer_zephyr',
      name: 'Artificer Zephyr',
      role: 'Arcane Clockwork Engineer',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/gnome.png',
      greeting: 'Careful around the steam pipes! Arcane capacitors can discharge 10,000 volts of lightning without warning.',
      dialogueOptions: [
        'Show me your clockwork inventions.',
        'Can you repair magical gadgets and rods?',
      ],
      shopItems: [
        'Clockwork Scout Automaton (75 Gold)',
        'Lightning Rod Battery (45 Gold)',
      ],
      canRecruit: true,
    ),
    MapNpc(
      id: 'npc_harbormaster_thorne',
      name: 'Harbormaster Thorne',
      role: 'Canal Port Authority',
      pos: const Point(0, 0),
      portraitAsset: 'assets/avatar/portraits/human.png',
      greeting: 'Keep moving, landlubbers. Three galleons from the eastern empire just docked with holds full of silk and spice.',
      dialogueOptions: [
        'What vessels are arriving in port?',
        'Any rumors of pirate activity off the coast?',
      ],
      canRecruit: false,
    ),
  ];

  for (final arch in archetypes) {
    Point? pos;
    for (int attempts = 0; attempts < 35; attempts++) {
      final room = city.rooms[rng.nextInt(city.rooms.length)];
      final tx = room.x + 1 + rng.nextInt(max(1, room.w - 2));
      final ty = room.y + 1 + rng.nextInt(max(1, room.h - 2));
      final k = '$tx,$ty';
      if (!taken.contains(k) && city.tileAt(tx, ty).walkable) {
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

List<MapAnimal> generateCityAnimals(DungeonMap city, {Set<String> excluding = const {}}) {
  final animals = <MapAnimal>[];
  final rng = Random(city.seed ^ 0x43414E49); // "CANI"
  final taken = Set<String>.from(excluding);

  final archetypes = [
    ('hound', 'Imperial Guard Mastiff', 'Armored guard hound standing tall beside the watchtower gate.', 'Woof! A deep, disciplined bark as the hound leans against your armor.', 'city_mastiff'),
    ('cat', 'Canal Wharves Calico', 'Sleek harbor mouser patrolling fish barrels and cargo quays.', 'Purr... The cat arches its back gracefully and accepts a stroke.', 'city_cat'),
    ('bird', 'Courier Carrier Pigeon', 'Trained homing pigeon perched on the guildhall mail ledge.', 'Coo! A cooing dove tilts its head, inspecting you calmly.', 'city_pigeon'),
    ('horse', 'Governor\'s White Stallion', 'Magnificent snow-white courser caparisoned in royal silk.', 'Neigh! The stallion snorts proudly and stamps an iron shoe on the stone.', 'city_stallion'),
    ('dog', 'Market Terrier', 'Energetic terrier darting playfully between bazaar canopies.', 'Yip-yip! The spirited pup wags its tail eagerly at your party.', 'city_terrier'),
    ('bird', 'Harbor Gull', 'Audacious white sea gull swooping around the canal docks.', 'Squawk! It tilts its beak and eyes your rations with bold interest.', 'city_gull'),
    ('hound', 'Patrician Poodle', 'Groomed curly-coated hound wearing a velvet collar.', 'Arf! It prances gracefully and accepts gentle head pats.', 'city_poodle'),
    ('cat', 'Guildhall Siamese', 'Striking blue-eyed cat resting upon parchment rolls.', 'Mrow... It purrs aloofly while sunning itself in a window.', 'city_siamese'),
  ];

  final count = 11 + rng.nextInt(4); // 11..14 animals
  for (int i = 0; i < count; i++) {
    final (species, name, flavor, dialogue, petId) = archetypes[i % archetypes.length];
    for (int attempts = 0; attempts < 35; attempts++) {
      final x = 3 + rng.nextInt(city.width - 6);
      final y = 3 + rng.nextInt(city.height - 6);
      final k = '$x,$y';
      if (!taken.contains(k) && city.tileAt(x, y).walkable) {
        taken.add(k);
        animals.add(MapAnimal(
          id: 'city_animal_${species}_$i',
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
