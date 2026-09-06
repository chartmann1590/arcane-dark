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
  ];
  final stallNames = [
    'Silk & Spice Bazaar Stall',
    'Enchanted Curios & Relics Cart',
    'Master Armorer''s Display Stall',
    'Apothecary & Herbalist Canopy',
  ];
  for (int i = 0; i < stallOffsets.length; i++) {
    final pt = stallOffsets[i];
    final key = '${pt.x},${pt.y}';
    if (!taken.contains(key) && city.tileAt(pt.x, pt.y).walkable) {
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
          name: 'Governor''s Gilded Seat of Law',
          interactionText: 'An elevated velvet throne backed by the golden seal of the High Imperial Council.',
        ));
        taken.add(key);
        break;

      case 2: // Grand Cathedral of the Sun
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_shrine.png',
          isSolid: true,
          name: 'High Radiant Altar of the Sun',
          interactionText: 'A massive sunstone dais glowing with warm, divine luminescence. Holy blessings wash over all who pray.',
        ));
        taken.add(key);
        break;

      case 3: // City Watch Barracks & Armory
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_weapon_rack.png',
          isSolid: true,
          name: 'City Watch Heavy Weapon Rack',
          interactionText: 'Sturdy iron racks bearing halberds, crossbows, and shields emblazoned with the city gryphon crest.',
        ));
        taken.add(key);
        break;

      case 4: // Harbor Guild & Vaults
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_chest_gilded.png',
          isSolid: true,
          name: 'Merchant Guild Bullion Coffer',
          interactionText: 'A triple-locked iron chest used for customs tariffs and maritime trade bullion.',
        ));
        taken.add(key);
        break;

      case 5: // Canal Docks
        props.add(MapProp(
          pos: center,
          asset: 'assets/tiles/prop_crates.png',
          isSolid: true,
          name: 'Harbor Shipping Crates & Barrels',
          interactionText: 'Sealed wooden crates stamped with royal customs seals, containing silk, rum, and dried spices.',
        ));
        taken.add(key);
        break;
    }
  }

  return props;
}

List<MapNpc> generateCityNpcs(DungeonMap city, {Set<String> excluding = const {}}) {
  final npcs = <MapNpc>[];
  final occupied = Set<String>.from(excluding);

  final npcsToPlace = [
    (
      id: 'npc_balthazar',
      name: 'Lord Balthazar',
      role: 'Grand Merchant Prince',
      roomIndex: 0,
      dx: 1,
      dy: -1,
      portrait: 'assets/portraits/merchant.png',
      greeting: 'Welcome, distinguished travelers! My bazaar carries wares from the highest astral spires to deepest dwarven mines. What do your coins desire today?',
      dialogue: [
        'What exotic curiosities do you have in stock?',
        'Have you heard any rumors regarding the city docks?',
        'I would like to trade some of my treasures.',
      ],
      shop: ['Potion of Superior Healing', 'Wand of Magic Missiles', 'Ring of Feather Falling', 'Elixir of True Sight', 'Boots of Speed'],
      canRecruit: false,
      heal: 0,
    ),
    (
      id: 'npc_marcus',
      name: 'Captain Marcus',
      role: 'High Watch Commander',
      roomIndex: 3,
      dx: 0,
      dy: 0,
      portrait: 'assets/portraits/paladin.png',
      greeting: 'Halt, citizens. The City Watch keeps order on these cobblestones. Keep your blades sheathed in the public square, and we will get along well.',
      dialogue: [
        'Are there any active bounties in the city?',
        'We encountered suspicious movements near the canal water gate.',
        'Would your steel march beside our party on dangerous quests?',
      ],
      shop: ['Steel Heater Shield', 'Heavy Crossbow', 'Quiver of 20 Bolts', 'Lantern of Revealing'],
      canRecruit: true,
      heal: 0,
    ),
    (
      id: 'npc_malachi',
      name: 'High Inquisitor Malachi',
      role: 'Patriarch of the Sun',
      roomIndex: 2,
      dx: 0,
      dy: 0,
      portrait: 'assets/portraits/cleric.png',
      greeting: 'May the undying dawn illuminate your path. In these troubled times, only the radiant light can shield the righteous from encroaching shadows.',
      dialogue: [
        'Please bestow the blessings of the Sun upon our party.',
        'We seek guidance on ancient evil sealed beneath the realm.',
        'Can your holy magic cleanse our afflictions?',
      ],
      shop: ['Potion of Greater Healing', 'Scroll of Revivify', 'Vial of Consecrated Holy Water', 'Sunstone Amulet'],
      canRecruit: false,
      heal: 35,
    ),
    (
      id: 'npc_shadow_jack',
      name: 'Slick Jack',
      role: 'Thieves'' Guild Informant',
      roomIndex: 0,
      dx: -4,
      dy: 2,
      portrait: 'assets/portraits/rogue.png',
      greeting: 'Psst! Keep your voice down and your eyes forward. If it exists in this metropolis—be it secret, lock, or contraband—Jack knows where it sleeps.',
      dialogue: [
        'What whispers circulate through the city underground?',
        'Do you have tools for picking difficult lock mechanisms?',
        'Join our crew; we need someone who treads silently.',
      ],
      shop: ['Masterwork Thieves'' Tools', 'Potion of Invisibility', 'Smokebomb of Shadow', 'Poisoner''s Vial'],
      canRecruit: true,
      heal: 0,
    ),
    (
      id: 'npc_kaelen',
      name: 'Harbor Master Kaelen',
      role: 'Canal Fleet Quartermaster',
      roomIndex: 5,
      dx: 0,
      dy: 0,
      portrait: 'assets/portraits/ranger.png',
      greeting: 'Ahoy! The tide brought in fresh cargo from the eastern straits this morning. Watch your step by the wet timbers.',
      dialogue: [
        'When does the next trade galleon depart?',
        'Any rumors of aquatic beasts lurking in the canals?',
        'I need maritime supplies and rope.',
      ],
      shop: ['50ft Silk Rope & Grapple', 'Mariner''s Compass', 'Spyglass of Farsight', 'Spiced Rum Rations'],
      canRecruit: false,
      heal: 0,
    ),
  ];

  for (final data in npcsToPlace) {
    if (data.roomIndex < city.rooms.length) {
      final room = city.rooms[data.roomIndex];
      final targetX = (room.centerX + data.dx).clamp(room.x + 1, room.x + room.w - 2);
      final targetY = (room.centerY + data.dy).clamp(room.y + 1, room.y + room.h - 2);
      final key = '$targetX,$targetY';

      if (!occupied.contains(key) && city.tileAt(targetX, targetY).walkable) {
        npcs.add(MapNpc(
          id: data.id,
          name: data.name,
          role: data.role,
          pos: Point(targetX, targetY),
          portraitAsset: data.portrait,
          greeting: data.greeting,
          dialogueOptions: data.dialogue,
          shopItems: data.shop,
          healPower: data.heal,
          canRecruit: data.canRecruit,
          maxHp: 20,
          currentHp: 20,
          armorClass: 14,
          attackBonus: 4,
          damageDice: 8,
          attackName: 'Steel Thrust',
        ));
        occupied.add(key);
      }
    }
  }

  return npcs;
}

List<MapAnimal> generateCityAnimals(DungeonMap city, {Set<String> excluding = const {}}) {
  final animals = <MapAnimal>[];
  final occupied = Set<String>.from(excluding);

  final animalDefs = [
    (
      id: 'city_warhorse',
      name: 'Clydesdale Carriage Horse',
      species: 'horse',
      roomIndex: 0,
      dx: 4,
      dy: 3,
      desc: 'A magnificent, muscled draught horse with braided mane, standing calmly by a market carriage.',
    ),
    (
      id: 'city_mastiff',
      name: 'Watch Mastiff "Goliath"',
      species: 'dog',
      roomIndex: 3,
      dx: -2,
      dy: 2,
      desc: 'A broad-chested guard mastiff wearing a studded leather collar, vigilantly sniffing every passerby.',
    ),
    (
      id: 'city_cat',
      name: 'Market Tabby "Miska"',
      species: 'cat',
      roomIndex: 0,
      dx: -3,
      dy: -3,
      desc: 'A clever striped street cat perched atop a crate of smoked fish, preening its whiskers in the sun.',
    ),
    (
      id: 'city_pigeon',
      name: 'Sun White Dove',
      species: 'bird',
      roomIndex: 2,
      dx: 2,
      dy: -2,
      desc: 'A peaceful white dove cooing softly from the cathedral balustrade, pecking at offering crumbs.',
    ),
    (
      id: 'city_rat',
      name: 'Canal Skitterer',
      species: 'rat',
      roomIndex: 5,
      dx: 1,
      dy: 2,
      desc: 'A plump canal rat chewing on an old rope splice near the water gate.',
    ),
  ];

  for (final def in animalDefs) {
    if (def.roomIndex < city.rooms.length) {
      final room = city.rooms[def.roomIndex];
      final targetX = (room.centerX + def.dx).clamp(room.x + 1, room.x + room.w - 2);
      final targetY = (room.centerY + def.dy).clamp(room.y + 1, room.y + room.h - 2);
      final key = '$targetX,$targetY';

      if (!occupied.contains(key) && city.tileAt(targetX, targetY).walkable) {
        animals.add(MapAnimal(
          id: def.id,
          name: def.name,
          species: def.species,
          pos: Point(targetX, targetY),
          iconType: def.species,
          flavor: def.desc,
          dialogue: 'The ${def.name} observes your party with keen attention.',
          canAdopt: true,
          petId: def.id,
        ));
        occupied.add(key);
      }
    }
  }

  return animals;
}
