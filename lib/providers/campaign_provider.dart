import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/campaign_state.dart';
import '../domain/campaign_seed.dart';
import '../domain/character.dart';
import '../domain/dm_turn_engine.dart';
import '../domain/item.dart';
import '../services/model_inference_service.dart';

class CampaignNotifier extends StateNotifier<CampaignState?> {
  CampaignNotifier([CampaignState? initial]) : super(initial) {
    if (initial == null) {
      loadPersisted();
    }
  }

  void startNew(CampaignSeed seed, List<Character> characters) {
    state = CampaignState.initial(seed: seed, characters: characters);
    _persist();
  }

  // GamePlayScreen calls engine.takeTurn()/companionBeat() directly (it needs
  // the token-streaming callback the simple takeTurn() wrapper below doesn't
  // expose) and then pushes the resulting CampaignState back in through here
  // — so this is actually where the vast majority of real gameplay mutations
  // (turns, companion beats, wandering, HP/inventory/quest changes) arrive.
  // It used to only update in-memory state, never writing to disk, so a full
  // app restart (or process death) would silently revert to whatever was
  // last saved by startNew/moveTo/etc — losing real play progress even
  // though everything looked fine as long as the app stayed alive. Persist
  // every time, same as every other mutating method here.
  void load(CampaignState s) {
    state = s;
    _persist();
  }

  /// Adds a character to the party of whatever campaign is currently active
  /// — used when recruiting an AI companion mid-adventure, so they join the
  /// story immediately instead of only appearing in campaigns started later.
  /// No-ops if there's no active campaign or the character's already in it.
  void addPartyMember(Character c) {
    final cur = state;
    if (cur == null) return;
    if (cur.party.any((m) => m.characterId == c.id)) return;
    cur.party = [...cur.party, PartyMemberStatus.fromCharacter(c)];
    state = cur;
    _persist();
  }

  void equipItem(String characterId, String item) {
    final cur = state;
    if (cur == null) return;
    for (final m in cur.party) {
      if (m.characterId == characterId && m.inventory.contains(item) && !m.equippedItems.contains(item)) {
        m.equippedItems = [...m.equippedItems, item];
      }
    }
    state = cur;
    _persist();
  }

  void unequipItem(String characterId, String item) {
    final cur = state;
    if (cur == null) return;
    for (final m in cur.party) {
      if (m.characterId == characterId) {
        m.equippedItems = m.equippedItems.where((e) => e != item).toList();
      }
    }
    state = cur;
    _persist();
  }

  /// Consumes a usable item (a potion/elixir/etc.) — heals the member by its
  /// rough flavor-driven amount (see ItemCatalog.healAmount) and removes it
  /// from inventory. No-op for non-consumable items.
  void useItem(String characterId, String item) {
    final cur = state;
    if (cur == null) return;
    for (final m in cur.party) {
      if (m.characterId == characterId && m.inventory.contains(item)) {
        final heal = ItemCatalog.healAmount(item);
        if (heal > 0) m.hp = (m.hp + heal).clamp(0, m.maxHp);
        m.inventory = List.from(m.inventory)..remove(item);
        m.equippedItems = m.equippedItems.where((e) => e != item).toList();
      }
    }
    state = cur;
    _persist();
  }

  void addItem(String characterId, String item) {
    final cur = state;
    if (cur == null) return;
    for (final m in cur.party) {
      if (m.characterId == characterId) {
        m.inventory = [...m.inventory, item];
      }
    }
    state = cur;
    _persist();
  }

  void updateHp(String characterId, int delta) {
    final cur = state;
    if (cur == null) return;
    for (final m in cur.party) {
      if (m.characterId == characterId) {
        m.hp = (m.hp + delta).clamp(0, m.maxHp);
      }
    }
    state = cur;
    _persist();
  }

  Future<void> takeTurn(String input, DmTurnEngine engine) async {
    final cur = state;
    if (cur == null) return;
    final res = await engine.takeTurn(playerInput: input, state: cur);
    state = res.updatedState;
    _persist();
  }

  void openDoor(int x, int y) {
    final cur = state;
    if (cur == null) return;
    final doors = cur.openedDoors;
    doors.add('$x,$y');
    cur.openedDoors = doors;
    state = cur;
    _persist();
  }

  void defeatEnemy(String enemyId) {
    final cur = state;
    if (cur == null) return;
    final enemies = cur.defeatedEnemies;
    enemies.add(enemyId);
    cur.defeatedEnemies = enemies;
    state = cur;
    _persist();
  }

  void newFloor({required int newSeed, required Point entryPoint, String environment = 'dungeon'}) {
    final cur = state;
    if (cur == null) return;
    final depth = (cur.worldFlags['dungeonDepth'] as int? ?? 0) + 1;
    cur.worldFlags['dungeonDepth'] = depth;
    cur.mapEnvironment = environment;
    cur.locationSeeds['dungeon_$depth'] = newSeed;
    cur.mapSeed = newSeed;
    cur.partyPosition = entryPoint;
    cur.visitedTiles = {'${entryPoint.x},${entryPoint.y}'};
    cur.openedDoors = {};
    cur.defeatedEnemies = {};
    for (final m in cur.party) {
      m.position = null;
    }
    state = cur;
    _persist();
  }

  Future<void> moveTo(Point p) async {
    if (state == null) return;
    state!.partyPosition = p;
    state!.visitedTiles.add('${p.x},${p.y}');
    // The lead (the player) always tracks the player's own moves exactly;
    // companions wander independently between turns instead of teleporting
    // in lockstep (see GamePlayScreen._wanderCompanions).
    if (state!.party.isNotEmpty) state!.party.first.position = p;
    state = state; // trigger notify
    _persist();
  }

  Future<void> _persist() async {
    if (state == null) return;
    final p = await SharedPreferences.getInstance();
    // persist last campaign only for MVP
    p.setString('last_campaign', jsonEncode(state!.toJson()));
  }

  Future<void> loadPersisted() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('last_campaign');
    if (raw != null) {
      try {
        state = CampaignState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }
}

final campaignProvider = StateNotifierProvider<CampaignNotifier, CampaignState?>((ref) => CampaignNotifier());

/// Real LiteRT-LM/Gemma 4 inference (see android/.../LlmEngine.kt + MainActivity.kt).
/// Android is this app's only shipping platform.
final modelServiceProvider = Provider<ModelInferenceService>((ref) => LiteRtModelInferenceService());
final dmEngineProvider = Provider<DmTurnEngine>((ref) => DmTurnEngine(model: ref.watch(modelServiceProvider)));
