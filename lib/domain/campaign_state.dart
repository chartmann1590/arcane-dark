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
  List<String> conditions;
  List<String> inventory;
  PartyMemberStatus({
    required this.characterId,
    required this.name,
    required this.raceLabel,
    required this.classLabel,
    required this.persona,
    required this.abilities,
    required this.hp,
    required this.maxHp,
    this.conditions = const [],
    this.inventory = const [],
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
        'conditions': conditions,
        'inventory': inventory,
      };
  factory PartyMemberStatus.fromJson(Map<String, dynamic> j) => PartyMemberStatus(
        characterId: j['characterId'],
        name: j['name'] as String? ?? 'Unknown',
        raceLabel: j['raceLabel'] as String? ?? '',
        classLabel: j['classLabel'] as String? ?? '',
        persona: j['persona'] as String? ?? '',
        abilities: j['abilities'] != null ? AbilityScores.fromJson(j['abilities'] as Map<String, dynamic>) : const AbilityScores(),
        hp: j['hp'],
        maxHp: j['maxHp'],
        conditions: (j['conditions'] as List?)?.cast<String>() ?? [],
        inventory: (j['inventory'] as List?)?.cast<String>() ?? [],
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
  Map<String, dynamic> worldFlags;
  String runningSummary;
  List<TurnLogEntry> recentTurns;
  String currentMapId;
  Point partyPosition;
  Set<String> visitedTiles;

  CampaignState({
    required this.campaignId,
    required this.seed,
    required this.currentSceneDescription,
    this.activeNpcs = const [],
    required this.party,
    this.questLog = const [],
    this.worldFlags = const {},
    this.runningSummary = '',
    this.recentTurns = const [],
    this.currentMapId = 'dungeon_0',
    this.partyPosition = const Point(0, 0),
    Set<String>? visitedTiles,
  }) : visitedTiles = visitedTiles ?? {};

  factory CampaignState.initial({required CampaignSeed seed, required List<Character> characters}) {
    return CampaignState(
      campaignId: seed.id,
      seed: seed,
      currentSceneDescription: 'You gather at ${seed.startingLocation}. ${seed.hook}',
      party: characters
          .map((c) => PartyMemberStatus(
                characterId: c.id,
                name: c.name,
                raceLabel: c.race.label,
                classLabel: c.charClass.label,
                persona: c.personaDescription,
                abilities: c.abilities,
                hp: c.hp,
                maxHp: c.hp,
                inventory: List.from(c.inventory),
              ))
          .toList(),
      questLog: seed.beats.asMap().entries.map((e) => QuestEntry(id: 'beat_${e.key}', title: e.value, stage: e.key == 0 ? 'active' : 'locked', status: e.key == 0 ? 'active' : 'locked')).toList(),
      worldFlags: {},
      runningSummary: 'Campaign "${seed.title}" begins at ${seed.startingLocation}.',
      recentTurns: [],
      currentMapId: 'dungeon_0',
      partyPosition: const Point(5, 5),
    );
  }

  Map<String, dynamic> toJson() => {
        'campaignId': campaignId,
        'seed': seed.toJson(),
        'currentSceneDescription': currentSceneDescription,
        'activeNpcs': activeNpcs.map((e) => e.toJson()).toList(),
        'party': party.map((e) => e.toJson()).toList(),
        'questLog': questLog.map((e) => e.toJson()).toList(),
        'worldFlags': worldFlags,
        'runningSummary': runningSummary,
        'recentTurns': recentTurns.map((e) => e.toJson()).toList(),
        'currentMapId': currentMapId,
        'partyPosition': {'x': partyPosition.x, 'y': partyPosition.y},
        'visitedTiles': visitedTiles.toList(),
      };
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
