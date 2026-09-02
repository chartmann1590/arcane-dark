import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/campaign_state.dart';
import '../domain/campaign_seed.dart';
import '../domain/character.dart';
import '../domain/dm_turn_engine.dart';
import '../services/model_inference_service.dart';

class CampaignNotifier extends StateNotifier<CampaignState?> {
  CampaignNotifier() : super(null);

  void startNew(CampaignSeed seed, List<Character> characters) {
    state = CampaignState.initial(seed: seed, characters: characters);
    _persist();
  }

  void load(CampaignState s) => state = s;

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

  Future<void> takeTurn(String input, DmTurnEngine engine) async {
    final cur = state;
    if (cur == null) return;
    final res = await engine.takeTurn(playerInput: input, state: cur);
    state = res.updatedState;
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
