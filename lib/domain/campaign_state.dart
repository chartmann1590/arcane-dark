import 'dart:math';
import 'ability_scores.dart';
import 'campaign_seed.dart';
import 'character.dart';
import 'persona.dart';

class NpcRef {
  final String id;
  final String name;
  final String disposition;
  NpcRef({required this.id, required this.name, this.disposition = 'neutral'});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'disposition': disposition};
  factory NpcRef.fromJson(Map<String, dynamic> j) => NpcRef(id: j['id'], name: j['name'], disposition: j['disposition'] ?? 'neutral');
}

class PartyMemberStatus {
  final String characterId;
  // Snapshotted at campaign start so the DM prompt can address each character
  // by name/persona without needing a separate character lookup at prompt time.
  final String name;
  final String raceLabel;
  final String classLabel;
  final String persona;
  final AbilityScores abilities;
  int hp;
  int maxHp;
  int armorClass;
  List<String> conditions;
  List<String> inventory;
  // Item names (a subset of inventory) the member currently has equipped —
  // purely a UI/roleplay flag since items are free-text, not stat blocks.
  List<String> equippedItems;
  // Where this specific member currently stands on the map — null means
  // "hasn't moved independently yet, render at the shared party position."
  // The lead always tracks the player's own moves; companions wander on
  // their own between turns (see GamePlayScreen._wanderCompanions) or jump
  // to a specific spot when the DM narrates them doing so (move_companion).
  Point? position;
  PartyMemberStatus({
    required this.characterId,
    required this.name,
    required this.raceLabel,
    required this.classLabel,
    required this.persona,
    required this.abilities,
    required this.hp,
    required this.maxHp,
    this.armorClass = 10,
    this.conditions = const [],
    this.inventory = const [],
    this.equippedItems = const [],
    this.position,
  });
  Map<String, dynamic> toJson() => {
        'characterId': characterId,
        'name': name,
        'raceLabel': raceLabel,
        'classLabel': classLabel,
        'persona': persona,
        'abilities': abilities.toJson(),
        'hp': hp,
        'maxHp': maxHp,
        'armorClass': armorClass,
        'conditions': conditions,
        'inventory': inventory,
        'equippedItems': equippedItems,
        if (position != null) 'position': {'x': position!.x, 'y': position!.y},
      };
  factory PartyMemberStatus.fromCharacter(Character c) => PartyMemberStatus(
        characterId: c.id,
        name: c.name,
        raceLabel: c.race.label,
        classLabel: c.charClass.label,
        persona: c.personaDescription,
        abilities: c.abilities,
        hp: c.hp,
        maxHp: c.hp,
        armorClass: c.armorClass,
        inventory: List.from(c.inventory),
      );
  factory PartyMemberStatus.fromJson(Map<String, dynamic> j) => PartyMemberStatus(
        characterId: j['characterId'],
        name: j['name'] as String? ?? 'Unknown',
        raceLabel: j['raceLabel'] as String? ?? '',
        classLabel: j['classLabel'] as String? ?? '',
        persona: j['persona'] as String? ?? '',
        abilities: j['abilities'] != null ? AbilityScores.fromJson(j['abilities'] as Map<String, dynamic>) : const AbilityScores(),
        hp: j['hp'],
        maxHp: j['maxHp'],
        armorClass: j['armorClass'] as int? ?? 10,
        conditions: (j['conditions'] as List?)?.cast<String>() ?? [],
        inventory: (j['inventory'] as List?)?.cast<String>() ?? [],
        equippedItems: (j['equippedItems'] as List?)?.cast<String>() ?? [],
        position: j['position'] != null ? Point(j['position']['x'], j['position']['y']) : null,
      );
}

class Sidequest {
  final String id;
  final String title;
  final String description;
  final String objective;
  final String category; // 'exploration', 'combat', 'puzzle', 'scavenge'
  final Point targetTile;
  final String rewardDescription;
  final int rewardXp;
  final String? rewardItem;
  bool isCompleted;
  bool isDiscovered;

  Sidequest({
    required this.id,
    required this.title,
    required this.description,
    required this.objective,
    this.category = 'exploration',
    required this.targetTile,
    this.rewardDescription = '100 XP',
    this.rewardXp = 100,
    this.rewardItem,
    this.isCompleted = false,
    this.isDiscovered = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'objective': objective,
        'category': category,
        'targetTile': {'x': targetTile.x, 'y': targetTile.y},
        'rewardDescription': rewardDescription,
        'rewardXp': rewardXp,
        'rewardItem': rewardItem,
        'isCompleted': isCompleted,
        'isDiscovered': isDiscovered,
      };

  factory Sidequest.fromJson(Map<String, dynamic> j) => Sidequest(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Mysterious Rumor',
        description: j['description'] as String? ?? '',
        objective: j['objective'] as String? ?? 'Investigate the area',
        category: j['category'] as String? ?? 'exploration',
        targetTile: Point(
          (j['targetTile']?['x'] as num?)?.toInt() ?? 0,
          (j['targetTile']?['y'] as num?)?.toInt() ?? 0,
        ),
        rewardDescription: j['rewardDescription'] as String? ?? '100 XP',
        rewardXp: (j['rewardXp'] as num?)?.toInt() ?? 100,
        rewardItem: j['rewardItem'] as String?,
        isCompleted: j['isCompleted'] as bool? ?? false,
        isDiscovered: j['isDiscovered'] as bool? ?? true,
      );
}

class QuestEntry {
  final String id;
  final String title;
  final String stage;
  final String status; // active, completed, failed
  QuestEntry({required this.id, required this.title, required this.stage, this.status = 'active'});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'stage': stage, 'status': status};
  factory QuestEntry.fromJson(Map<String, dynamic> j) => QuestEntry(id: j['id'], title: j['title'], stage: j['stage'], status: j['status'] ?? 'active');
}

class TurnLogEntry {
  final String playerInput;
  final String dmResponse;
  final DateTime at;
  TurnLogEntry({required this.playerInput, required this.dmResponse, DateTime? at}) : at = at ?? DateTime.now();
  Map<String, dynamic> toJson() => {'playerInput': playerInput, 'dmResponse': dmResponse, 'at': at.toIso8601String()};
  factory TurnLogEntry.fromJson(Map<String, dynamic> j) => TurnLogEntry(playerInput: j['playerInput'], dmResponse: j['dmResponse'], at: DateTime.tryParse(j['at'] ?? ''));
}

class CampaignState {
  final String campaignId;
  final CampaignSeed seed;
  String currentSceneDescription;
  List<NpcRef> activeNpcs;
  List<PartyMemberStatus> party;
  List<QuestEntry> questLog;
  List<Sidequest> sidequests;
  Map<String, dynamic> worldFlags;
  String runningSummary;
  List<TurnLogEntry> recentTurns;
  String currentMapId;
  Point partyPosition;
  Set<String> visitedTiles;
  // The dungeon layout is deterministic from this seed — generated once when
  // the campaign starts and persisted from then on, so returning to the Play
  // screen always shows the *same* map instead of a fresh random one. Only
  // an explicit "New Dungeon" action or a brand-new campaign changes it.
  int mapSeed;
  // Which tile art the CURRENT map uses ('tavern' or 'dungeon') — re-derived
  // every turn from the DM's own narration (see environmentFor), not fixed
  // once at campaign start, so walking from a tavern into a crypt actually
  // changes what the map looks like.
  String mapEnvironment;
  // One remembered map seed per environment the party has ever visited in
  // this campaign — switching back to an environment reuses its seed (so the
  // same tavern, with the same NPCs and furniture, is still there) instead
  // of rolling a brand-new random layout every time.
  Map<String, int> locationSeeds;

  CampaignState({
    required this.campaignId,
    required this.seed,
    required this.currentSceneDescription,
    this.activeNpcs = const [],
    required this.party,
    this.questLog = const [],
    List<Sidequest>? sidequests,
    this.worldFlags = const {},
    this.runningSummary = '',
    this.recentTurns = const [],
    this.currentMapId = 'dungeon_0',
    this.partyPosition = const Point(0, 0),
    Set<String>? visitedTiles,
    int? mapSeed,
    String? mapEnvironment,
    Map<String, int>? locationSeeds,
  })  : sidequests = sidequests ?? defaultSidequestsFor(seed),
        visitedTiles = visitedTiles ?? {},
        mapSeed = mapSeed ?? Random().nextInt(1 << 30),
        mapEnvironment = mapEnvironment ?? 'dungeon',
        locationSeeds = locationSeeds ?? {} {
    this.locationSeeds.putIfAbsent(this.mapEnvironment, () => this.mapSeed);
  }

  /// Environment inferred from narration or location text — automatically sets
  /// the active map mode to forest wilderness, village town, underground caverns,
  /// warm tavern interiors, or stone dungeon crypts.
  static String environmentFor(String text) {
    final l = text.toLowerCase();
    const forestWords = ['forest', 'woods', 'woodland', 'grove', 'glade', 'jungle', 'wilds', 'wilderness', 'trail', 'clearing', 'canopy', 'timber'];
    for (final w in forestWords) {
      if (l.contains(w)) return 'forest';
    }
    const villageWords = ['village', 'town', 'city', 'market', 'plaza', 'street', 'bazaar', 'hamlet', 'district', 'square', 'quarter', 'blacksmith', 'apothecary'];
    for (final w in villageWords) {
      if (l.contains(w)) return 'village';
    }
    const caveWords = ['cave', 'cavern', 'grotto', 'mine', 'chasm', 'underdark', 'fissure', 'geode', 'subterranean'];
    for (final w in caveWords) {
      if (l.contains(w)) return 'cave';
    }
    const tavernWords = ['tavern', 'inn', 'pub', 'bar', 'alehouse', 'parlor'];
    for (final w in tavernWords) {
      if (l.contains(w)) return 'tavern';
    }
    return 'dungeon';
  }

  /// Opened door coordinates 'x,y' persisted across tab switches and resumes.
  Set<String> get openedDoors =>
      worldFlags['openedDoors'] != null ? Set<String>.from(worldFlags['openedDoors'] as List) : <String>{};

  set openedDoors(Set<String> doors) {
    worldFlags['openedDoors'] = doors.toList();
  }

  /// Defeated enemy IDs persisted across tab switches and resumes.
  Set<String> get defeatedEnemies =>
      worldFlags['defeatedEnemies'] != null ? Set<String>.from(worldFlags['defeatedEnemies'] as List) : <String>{};

  set defeatedEnemies(Set<String> enemies) {
    worldFlags['defeatedEnemies'] = enemies.toList();
  }

  /// The seed to use for [env] — reuses whatever this campaign already
  /// generated for that environment, or rolls (and remembers) a fresh one.
  int seedForEnvironment(String env) => locationSeeds.putIfAbsent(env, () => Random().nextInt(1 << 30));

  static List<Sidequest> defaultSidequestsFor(CampaignSeed seed) {
    return [
      Sidequest(
        id: 'sq_altar_relic',
        title: 'The Mystic Shrine',
        description: 'An ancient consecrated obelisk hums with restorative power in a secluded chamber.',
        objective: 'Locate and commune with the Mystic Shrine or Altar',
        category: 'puzzle',
        targetTile: const Point(8, 6),
        rewardDescription: '120 XP & Ring of Protection',
        rewardXp: 120,
        rewardItem: 'Ring of Protection (+1 AC)',
      ),
      Sidequest(
        id: 'sq_crypt_scavenge',
        title: 'Lost Munitions Cache',
        description: 'Valuable pioneer supplies and gold lie hidden in abandoned coffer boxes or supply barrels.',
        objective: 'Open and loot an iron chest, gilded coffer, or supply crate',
        category: 'scavenge',
        targetTile: const Point(14, 12),
        rewardDescription: '100 XP & 50 Gold Pieces',
        rewardXp: 100,
        rewardItem: 'Pouch of 50 Royal Gold Pieces',
      ),
      Sidequest(
        id: 'sq_beast_cull',
        title: 'Crypt Cleansing Bounty',
        description: 'Vile undead horrors stalk the subterranean corridors, threatening the realm above.',
        objective: 'Defeat at least 2 hostile crypt stalkers',
        category: 'combat',
        targetTile: const Point(6, 16),
        rewardDescription: '150 XP & Elixir of Giant Strength',
        rewardXp: 150,
        rewardItem: 'Elixir of Giant Strength (+2 STR)',
      ),
      Sidequest(
        id: 'sq_cartographer',
        title: 'Delve Cartography',
        description: 'Explore the gloomy depths and chart unknown rooms and corridors.',
        objective: 'Chart at least 25 dungeon tiles and uncover secret chambers',
        category: 'exploration',
        targetTile: const Point(18, 8),
        rewardDescription: '140 XP & Boots of Elvenkind',
        rewardXp: 140,
        rewardItem: 'Boots of Elvenkind (Advantage on Stealth)',
      ),
    ];
  }

  factory CampaignState.initial({required CampaignSeed seed, required List<Character> characters}) {
    return CampaignState(
      campaignId: seed.id,
      seed: seed,
      currentSceneDescription: 'You gather at ${seed.startingLocation}. ${seed.hook}',
      party: characters.map(PartyMemberStatus.fromCharacter).toList(),
      questLog: seed.beats.asMap().entries.map((e) => QuestEntry(id: 'beat_${e.key}', title: e.value, stage: e.key == 0 ? 'active' : 'locked', status: e.key == 0 ? 'active' : 'locked')).toList(),
      sidequests: defaultSidequestsFor(seed),
      worldFlags: {},
      runningSummary: 'Campaign "${seed.title}" begins at ${seed.startingLocation}.',
      recentTurns: [],
      currentMapId: 'dungeon_0',
      partyPosition: const Point(5, 5),
      mapEnvironment: environmentFor(seed.startingLocation),
    );
  }

  Map<String, dynamic> toJson() => {
        'campaignId': campaignId,
        'seed': seed.toJson(),
        'currentSceneDescription': currentSceneDescription,
        'activeNpcs': activeNpcs.map((e) => e.toJson()).toList(),
        'party': party.map((e) => e.toJson()).toList(),
        'questLog': questLog.map((e) => e.toJson()).toList(),
        'sidequests': sidequests.map((e) => e.toJson()).toList(),
        'worldFlags': worldFlags,
        'runningSummary': runningSummary,
        'recentTurns': recentTurns.map((e) => e.toJson()).toList(),
        'currentMapId': currentMapId,
        'partyPosition': {'x': partyPosition.x, 'y': partyPosition.y},
        'visitedTiles': visitedTiles.toList(),
        'mapSeed': mapSeed,
        'mapEnvironment': mapEnvironment,
        'locationSeeds': locationSeeds,
      };

  /// Mirrors [toJson] — used both for local (SharedPreferences) persistence
  /// and for reconstructing the host's synced state on other players'
  /// devices (see SessionRepository.pushState/watchState).
  factory CampaignState.fromJson(Map<String, dynamic> j) {
    final seed = CampaignSeed.fromJson(j['seed'] as Map<String, dynamic>);
    return CampaignState(
        campaignId: j['campaignId'],
        seed: seed,
        currentSceneDescription: j['currentSceneDescription'],
        activeNpcs: (j['activeNpcs'] as List? ?? []).map((e) => NpcRef.fromJson(e as Map<String, dynamic>)).toList(),
        party: (j['party'] as List).map((e) => PartyMemberStatus.fromJson(e as Map<String, dynamic>)).toList(),
        questLog: (j['questLog'] as List).map((e) => QuestEntry.fromJson(e as Map<String, dynamic>)).toList(),
        sidequests: (j['sidequests'] as List? ?? []).isNotEmpty
            ? (j['sidequests'] as List).map((e) => Sidequest.fromJson(e as Map<String, dynamic>)).toList()
            : defaultSidequestsFor(seed),
        worldFlags: Map<String, dynamic>.from(j['worldFlags'] ?? {}),
        runningSummary: j['runningSummary'] ?? '',
        recentTurns: (j['recentTurns'] as List? ?? []).map((e) => TurnLogEntry.fromJson(e as Map<String, dynamic>)).toList(),
        currentMapId: j['currentMapId'] ?? 'dungeon_0',
        partyPosition: Point(j['partyPosition']['x'], j['partyPosition']['y']),
        visitedTiles: Set<String>.from(j['visitedTiles'] ?? []),
        mapSeed: j['mapSeed'] as int?,
        mapEnvironment: j['mapEnvironment'] as String?,
        locationSeeds: (j['locationSeeds'] as Map?)?.map((k, v) => MapEntry(k as String, v as int)),
      );
  }
}

class Point {
  final int x;
  final int y;
  const Point(this.x, this.y);
  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => '($x,$y)';
}
