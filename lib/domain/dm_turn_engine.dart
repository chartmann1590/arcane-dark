import 'dart:async';
import 'dart:math';
import 'campaign_state.dart';
import 'dm_tools.dart';
import '../services/model_inference_service.dart';

class DmTurnResult {
  final String narration;
  final CampaignState updatedState;
  final DiceResult? dice;
  DmTurnResult({required this.narration, required this.updatedState, this.dice});
}

class DmTurnEngine {
  final ModelInferenceService model;
  final DmTools tools;
  DmTurnEngine({required this.model, DmTools? tools}) : tools = tools ?? DmTools();

  // Approximate token count: char/4
  int _approxTokens(String text) => (text.length / 4).ceil();

  String _assemblePrompt(CampaignState state, String playerInput) {
    final sb = StringBuffer();
    sb.writeln('You are an expert Dungeon Master. Narrate in-character, never break the fourth wall.');
    sb.writeln('Campaign: ${state.seed.title} | Tone: ${state.seed.tone}');
    sb.writeln('Setting: ${state.seed.setting}');
    sb.writeln('Current scene: ${state.currentSceneDescription}');
    sb.writeln('Party position: ${state.partyPosition} on map ${state.currentMapId}');
    sb.writeln('World flags: ${state.worldFlags}');
    sb.writeln('Summary: ${state.runningSummary}');
    sb.writeln('\nRecent turns:');
    for (final t in state.recentTurns.take(6)) {
      sb.writeln('Player: ${t.playerInput}');
      sb.writeln('DM: ${t.dmResponse}');
    }
    sb.writeln('\nAvailable actions: roll_dice(sides,count,modifier), update_hp(target,delta), add_item(target,item), move_party(x,y), trigger_encounter(id), advance_quest(id,stage)');
    sb.writeln('Use <<ACTION: name key=val>> when you need to roll or mutate state. Otherwise just narrate.');
    sb.writeln('\nPlayer now says: $playerInput');
    sb.writeln('\nRespond as DM:');
    return sb.toString();
  }

  void _maybeSummarize(CampaignState state) {
    final approx = _approxTokens(state.runningSummary) + state.recentTurns.fold(0, (a, e) => a + _approxTokens(e.dmResponse));
    // LiteRT context ~4k, keep at 70% = 2800 tokens
    if (approx > 2600 && state.recentTurns.length > 6) {
      final toCompress = state.recentTurns.take(state.recentTurns.length ~/ 2).toList();
      final compressed = toCompress.map((e) => '${e.playerInput} -> ${e.dmResponse.substring(0, min(120, e.dmResponse.length))}').join(' | ');
      state.runningSummary += ' $compressed';
      state.recentTurns = state.recentTurns.sublist(toCompress.length);
    }
  }

  Future<DmTurnResult> takeTurn({required String playerInput, required CampaignState state, void Function(String chunk)? onToken}) async {
    final prompt = _assemblePrompt(state, playerInput);
    final buffer = StringBuffer();
    await for (final chunk in model.generate(prompt, maxTokens: 512)) {
      buffer.write(chunk);
      onToken?.call(chunk);
    }
    final raw = buffer.toString();

    // Parse any action blocks
    var narration = raw;
    DiceResult? diceResult;
    final action = DmTools.parseAction(raw);
    if (action != null) {
      final act = action['action']!;
      try {
        switch (act) {
          case 'roll_dice':
            final sides = int.tryParse(action['sides'] ?? '20') ?? 20;
            final count = int.tryParse(action['count'] ?? '1') ?? 1;
            final mod = int.tryParse(action['modifier'] ?? '0') ?? 0;
            diceResult = tools.rollDice(sides: sides, count: count, modifier: mod);
            narration = DmTools.stripActionBlocks(raw);
            if (narration.isEmpty) {
              narration = diceResult.total >= 15
                  ? 'Fate smiles upon you — the roll succeeds! (${diceResult.rolls.join(",")} + $mod = ${diceResult.total})'
                  : 'The attempt falters... (${diceResult.rolls.join(",")} + $mod = ${diceResult.total})';
            } else {
              narration += '\n\n[Roll: ${diceResult.rolls.join(", ")} + $mod = ${diceResult.total}]';
            }
            break;
          case 'update_hp':
            final target = action['target'] ?? state.party.first.characterId;
            final delta = int.tryParse(action['delta'] ?? '0') ?? 0;
            tools.updateHp(state, target, delta);
            narration = DmTools.stripActionBlocks(raw);
            break;
          case 'add_item':
            final target = action['target'] ?? state.party.first.characterId;
            final item = action['item'] ?? 'mysterious trinket';
            tools.addItem(state, target, item);
            narration = DmTools.stripActionBlocks(raw);
            break;
          case 'move_party':
            final x = int.tryParse(action['x'] ?? action['destination'] ?? '0') ?? state.partyPosition.x;
            final y = int.tryParse(action['y'] ?? '1') ?? state.partyPosition.y + 1;
            tools.moveParty(state, Point(x, y));
            narration = DmTools.stripActionBlocks(raw);
            break;
          case 'trigger_encounter':
            final id = action['encounter_id'] ?? action['id'] ?? 'unknown';
            tools.triggerEncounter(state, id);
            narration = DmTools.stripActionBlocks(raw);
            break;
          case 'advance_quest':
            final qid = action['quest_id'] ?? action['id'] ?? state.questLog.first.id;
            final stage = action['stage'] ?? 'completed';
            tools.advanceQuest(state, qid, stage);
            narration = DmTools.stripActionBlocks(raw);
            break;
          default:
            narration = DmTools.stripActionBlocks(raw);
        }
      } catch (_) {
        narration = DmTools.stripActionBlocks(raw);
      }
    } else {
      // No action block — if player said attack/roll, synthesize a fallback roll
      final lower = playerInput.toLowerCase();
      if (lower.contains('attack') || lower.contains('roll') || lower.contains('strike')) {
        diceResult = tools.rollDice(sides: 20, count: 1, modifier: 3);
        narration += '\n\n[Roll: d20 = ${diceResult.total} (${diceResult.rolls.first} + 3)]';
      }
      narration = DmTools.stripActionBlocks(narration);
      if (narration.trim().isEmpty) narration = raw;
    }

    // Strip any leaked action fragments just in case (safety filter from Phase 09)
    narration = narration.replaceAll(RegExp(r'<<ACTION:[^>]*>>?'), '').trim();
    if (narration.isEmpty) narration = 'The air hangs heavy as you consider your next move...';

    state.recentTurns = [
      ...state.recentTurns,
      TurnLogEntry(playerInput: playerInput, dmResponse: narration),
    ];
    if (narration.length > 200) {
      state.currentSceneDescription = narration.substring(0, 200);
    }
    _maybeSummarize(state);

    return DmTurnResult(narration: narration, updatedState: state, dice: diceResult);
  }
}
