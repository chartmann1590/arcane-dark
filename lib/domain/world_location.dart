import 'package:flutter/material.dart';

/// Represents a distinct realm, city, or dungeon on the fantasy World Atlas.
class WorldLocation {
  final String id;
  final String name;
  final String regionTitle;
  final String subtitle;
  final String description;
  final double normX; // 0.0 to 1.0 on world map canvas
  final double normY; // 0.0 to 1.0 on world map canvas
  final IconData icon;
  final Color primaryColor;
  final Color accentColor;
  final String threatLevel;
  final List<String> landmarks;
  final List<String> notableNpcs;
  final List<String> localAmenities;
  final String rumorClue;

  const WorldLocation({
    required this.id,
    required this.name,
    required this.regionTitle,
    required this.subtitle,
    required this.description,
    required this.normX,
    required this.normY,
    required this.icon,
    required this.primaryColor,
    required this.accentColor,
    required this.threatLevel,
    required this.landmarks,
    required this.notableNpcs,
    required this.localAmenities,
    required this.rumorClue,
  });

  String get shortName {
    switch (id) {
      case 'castle':
        return 'Valoria';
      case 'forest':
        return 'Whisper Woods';
      case 'village':
        return 'Oakhaven';
      case 'tavern':
        return 'Gilded Goblet';
      case 'city':
        return 'Highgate';
      case 'cave':
        return 'Crystal Caves';
      case 'dungeon':
        return 'Catacombs';
      default:
        return name.split(' ').first;
    }
  }
}

/// Trade route connecting two world locations on the map.
class WorldTradeRoute {
  final String fromId;
  final String toId;
  final String name;
  final String travelTime;

  const WorldTradeRoute({
    required this.fromId,
    required this.toId,
    required this.name,
    required this.travelTime,
  });
}

/// Catalog of all canonical world locations and connecting highways in the realm.
class WorldLocationCatalog {
  static const List<WorldLocation> locations = [
    WorldLocation(
      id: 'castle',
      name: 'Valoria Citadel',
      regionTitle: 'Kingdom of Valoria • High Crags',
      subtitle: 'Royal Fortress & High Stronghold',
      description:
          'The sovereign mountain seat of King Alden the Just, defended by an impassable perimeter moat, heavy drawbridge, sovereign Golden Lion Throne, and the Kingsguard armory.',
      normX: 0.50,
      normY: 0.16,
      icon: Icons.fort_rounded,
      primaryColor: Color(0xFFAB47BC),
      accentColor: Color(0xFFFFD700),
      threatLevel: 'Moderate-High',
      landmarks: [
        'Sovereign Water Moat & Drawbridge',
        'Golden Lion Throne Room',
        'Royal Feast Banquet Hall',
        'Kingsguard Armory & Spire',
      ],
      notableNpcs: [
        'King Alden the Just',
        'Grand Marshal Cedric',
        'Archmage Vane',
        'Pip the Jester',
      ],
      localAmenities: [
        'Royal Decree Audiences',
        'Kingsguard Weapon Tempering',
        'Feast Table Provisions',
      ],
      rumorClue:
          'Heralds speak of King Alden\'s sovereign fortress nestled high in the northern crags, flying royal purple and gold banners.',
    ),
    WorldLocation(
      id: 'forest',
      name: 'Whispering Woods',
      regionTitle: 'The Emerald Canopy • Primeval Wilds',
      subtitle: 'Towering Wilderness & Rushing Rivers',
      description:
          'A vast, untouched primeval woodland woven with ancient roots, sun-dappled game trails, crystal river footbridges, druidic stone circles, and wild beasts.',
      normX: 0.18,
      normY: 0.40,
      icon: Icons.forest_rounded,
      primaryColor: Color(0xFF4E9A51),
      accentColor: Color(0xFF81C784),
      threatLevel: 'Moderate',
      landmarks: [
        'Towering Ancient Canopy Trees',
        'Rushing River Footbridges',
        'Druidic Moss Dais',
        'Wild Game Footpaths',
      ],
      notableNpcs: [
        'Ranger Sylvie',
        'Elder Thorne the Druid',
        'Woodland Scouts',
        'Wild Wolves & Stags',
      ],
      localAmenities: [
        'Herbalist Foraging',
        'River Rest Sanctuary',
        'Nature Attunement',
      ],
      rumorClue:
          'Woodland rangers whisper of ancient living canopy trees to the west where primal nature magic hums in the damp moss.',
    ),
    WorldLocation(
      id: 'village',
      name: 'Oakhaven Village',
      regionTitle: 'The Lowland Shires • Mill Valley',
      subtitle: 'Civilized Township & Farmlands',
      description:
          'A cheerful, cobblestone hamlet centered around a crystal town square water fountain, master blacksmith forge, rustic cottages, and friendly townsfolk.',
      normX: 0.44,
      normY: 0.44,
      icon: Icons.location_city_rounded,
      primaryColor: Color(0xFFE5A93C),
      accentColor: Color(0xFFFFE082),
      threatLevel: 'Low',
      landmarks: [
        'Town Square Sun Fountain',
        'Blacksmith Anvil & Forge',
        'Rustic Thatched Cottages',
        'Timber Watermill',
      ],
      notableNpcs: [
        'Blacksmith Torvald',
        'Town Elder Alistair',
        'Constable Bran',
        'Village Mastiffs',
      ],
      localAmenities: [
        'Forge Weapon Tempering',
        'Town Fountain Wishes',
        'Village General Goods',
      ],
      rumorClue:
          'The central crossroad settlement of the realm, renowned for warm hospitality, fresh wellsprings, and skilled blacksmiths.',
    ),
    WorldLocation(
      id: 'tavern',
      name: 'The Gilded Goblet',
      regionTitle: 'The Golden Crossway • Wayfarer\'s Rest',
      subtitle: 'Warm Sanctuary & Waystation',
      description:
          'A bustling timber inn bathed in the glow of a roaring fireplace hearth. Filled with traveling bards, lively dice tables, spiced tavern ale, and fellow companions.',
      normX: 0.60,
      normY: 0.52,
      icon: Icons.sports_bar_rounded,
      primaryColor: Color(0xFFD97706),
      accentColor: Color(0xFFFFB300),
      threatLevel: 'Safe Haven',
      landmarks: [
        'Roaring Timber Fireplace',
        'Polished Oak Barkeep Counter',
        'Gambling & Dice Tables',
        'Bardic Performance Stage',
      ],
      notableNpcs: [
        'Barkeep Barnaby',
        'Minstrel Lyra',
        'Traveling Mercenaries',
        'Tavern Hound',
      ],
      localAmenities: [
        'Rest & Full HP Recovery',
        'Companion Tactical Banter',
        'Adventurer Rumor Board',
      ],
      rumorClue:
          'The most famous waystation along the King\'s Road, where weary travelers find shelter, warm hearth fires, and cold tankards.',
    ),
    WorldLocation(
      id: 'city',
      name: 'Highgate Metropolis',
      regionTitle: 'Highgate Bay • Maritime Straits',
      subtitle: 'Grand City, Canals & Grand Bazaar',
      description:
          'A roaring maritime trading capital paved in broad ashlar limestone. Famous for its eastern canal waterways with arched footbridges, bustling Grand Bazaar stalls, and the soaring Cathedral of the Sun.',
      normX: 0.82,
      normY: 0.36,
      icon: Icons.apartment_rounded,
      primaryColor: Color(0xFFE5A93C),
      accentColor: Color(0xFF4FC3F7),
      threatLevel: 'Low-Moderate',
      landmarks: [
        'Grand Market Bazaar Plaza',
        'Canal Waterway & Stone Bridges',
        'High Cathedral of the Sun',
        'Harbor Watch Barracks',
      ],
      notableNpcs: [
        'Lord Balthazar (Merchant Prince)',
        'Captain Marcus (Watch Commander)',
        'High Inquisitor Malachi',
        'Slick Jack (Dock Smuggler)',
      ],
      localAmenities: [
        'Bazaar Curio & Potion Shops',
        'Sunlight Altar Blessings',
        'Harbor Trade Barges',
      ],
      rumorClue:
          'The sprawling trade metropolis to the east, where merchant galleons dock along stone canals and silk canopies flutter.',
    ),
    WorldLocation(
      id: 'cave',
      name: 'Crystalline Caverns',
      regionTitle: 'The Obsidian Rift • Underdark Fissures',
      subtitle: 'Subterranean Abyss & Glowing Geodes',
      description:
          'A wondrous subterranean chasm sparkling with luminous amethyst crystals, subterranean reflecting pools, deep cave fauna, and ancient dwarven mine carts.',
      normX: 0.30,
      normY: 0.78,
      icon: Icons.terrain_rounded,
      primaryColor: Color(0xFF5B8DEF),
      accentColor: Color(0xFF80DEEA),
      threatLevel: 'High',
      landmarks: [
        'Luminous Geode Clusters',
        'Subterranean Crystal Pools',
        'Abandoned Dwarven Mine Rails',
        'Obsidian Fissure Chasm',
      ],
      notableNpcs: [
        'Dwarven Prospector Thrum',
        'Geode Weaver Mira',
        'Cavern Bats & Spiders',
        'Subterranean Salamanders',
      ],
      localAmenities: [
        'Crystal Geode Harvesting',
        'Subterranean Pool Rest',
        'Underdark Mineral Trade',
      ],
      rumorClue:
          'Deep underground beneath the southern rift, pulsing geodes cast eerie violet light over ancient dwarven mine shafts.',
    ),
    WorldLocation(
      id: 'dungeon',
      name: 'Ancient Catacombs',
      regionTitle: 'The Ashen Wastes • Forgotten Crypts',
      subtitle: 'Subterranean Vault & Trapped Corridors',
      description:
          'A subterranean complex of interlocking clockwork gears, damp stone crypts, steam piston gates, ancient sarcophagi, and roaming automaton sentries.',
      normX: 0.72,
      normY: 0.80,
      icon: Icons.castle_rounded,
      primaryColor: Color(0xFF9E77ED),
      accentColor: Color(0xFFE57373),
      threatLevel: 'Extreme',
      landmarks: [
        'Steam Piston Gatehouse',
        'Ancient Stone Sarcophagi',
        'Heavy Iron Portcullis Gates',
        'Chrono-Core Mechanism',
      ],
      notableNpcs: [
        'Overclocked Arch-Mechanist Zael',
        'Clockwork Automaton Sentinels',
        'Crypt Stalkers',
        'Vault Guardians',
      ],
      localAmenities: [
        'Ancient Relic Coffers',
        'Runic Cipher Chambers',
        'Lost Weapon Armaments',
      ],
      rumorClue:
          'A treacherous subterranean ruin buried beneath the wastes, humming with forgotten mechanical power and guarded by sentinels.',
    ),
  ];

  static const List<WorldTradeRoute> tradeRoutes = [
    WorldTradeRoute(fromId: 'castle', toId: 'village', name: 'The Royal North Highway', travelTime: '1 Day by Carriage'),
    WorldTradeRoute(fromId: 'village', toId: 'forest', name: 'The Westwood Trail', travelTime: 'Half Day on Foot'),
    WorldTradeRoute(fromId: 'village', toId: 'tavern', name: 'The Pilgrim\'s Crossroad', travelTime: '4 Hours on Foot'),
    WorldTradeRoute(fromId: 'tavern', toId: 'city', name: 'The Merchant\'s Highroad', travelTime: '6 Hours by Wagon'),
    WorldTradeRoute(fromId: 'city', toId: 'dungeon', name: 'The Ashen Coast Highway', travelTime: '1 Day Journey'),
    WorldTradeRoute(fromId: 'village', toId: 'cave', name: 'The Old Miner\'s Pass', travelTime: '1 Day Trek'),
    WorldTradeRoute(fromId: 'cave', toId: 'dungeon', name: 'The Deep Subterranean Way', travelTime: 'Subterranean Passage'),
  ];

  static WorldLocation? getById(String id) {
    return locations.where((l) => l.id == id).firstOrNull;
  }
}
