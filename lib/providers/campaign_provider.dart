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
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final seed = CampaignSeed.fromJson(j['seed'] as Map<String, dynamic>);
        // Reconstruct minimal CampaignState
        final cs = CampaignState(
          campaignId: j['campaignId'],
          seed: seed,
          currentSceneDescription: j['currentSceneDescription'],
          party: (j['party'] as List).map((e) => PartyMemberStatus.fromJson(e as Map<String, dynamic>)).toList(),
          questLog: (j['questLog'] as List).map((e) => QuestEntry.fromJson(e as Map<String, dynamic>)).toList(),
          worldFlags: Map<String, dynamic>.from(j['worldFlags'] ?? {}),
          runningSummary: j['runningSummary'] ?? '',
          recentTurns: (j['recentTurns'] as List? ?? []).map((e) => TurnLogEntry.fromJson(e as Map<String, dynamic>)).toList(),
          currentMapId: j['currentMapId'] ?? 'dungeon_0',
          partyPosition: Point(j['partyPosition']['x'], j['partyPosition']['y']),
          visitedTiles: Set<String>.from(j['visitedTiles'] ?? []),
        );
        state = cs;
      } catch (_) {}
    }
  }
}

final campaignProvider = StateNotifierProvider<CampaignNotifier, CampaignState?>((ref) => CampaignNotifier());

/// Real LiteRT-LM/Gemma 4 inference (see android/.../LlmEngine.kt + MainActivity.kt).
/// Android is this app's only shipping platform.
final modelServiceProvider = Provider<ModelInferenceService>((ref) => LiteRtModelInferenceService());
final dmEngineProvider = Provider<DmTurnEngine>((ref) => DmTurnEngine(model: ref.watch(modelServiceProvider)));
