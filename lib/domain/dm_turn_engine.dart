import 'dart:async';
import 'dart:math';
import 'campaign_state.dart';
import 'dm_tools.dart';
import '../services/model_inference_service.dart';

class DmTurnResult {
  final String narration;
  final CampaignState updatedState;
  final DiceResult? dice;
  final CheckResult? check;
  final AttackResult? attack;
  DmTurnResult({required this.narration, required this.updatedState, this.dice, this.check, this.attack});

  /// True if anything roll-shaped happened this turn — used by the UI to
  /// decide whether to play the dice SFX / show a roll badge.
  bool get hadRoll => dice != null || check != null || attack != null;
}

class DmTurnEngine {
  final ModelInferenceService model;
  final DmTools tools;
  DmTurnEngine({required this.model, DmTools? tools}) : tools = tools ?? DmTools();

  // Approximate token count: char/4
  int _approxTokens(String text) => (text.length / 4).ceil();

  String _assemblePrompt(CampaignState state, String playerInput, {String? addressedTo}) {
    final sb = StringBuffer();
    sb.writeln('You are an expert Dungeon Master running a Dungeons & Dragons style game. Narrate in second person, in-character, and never break the fourth wall.');
    sb.writeln('Campaign: ${state.seed.title} | Tone: ${state.seed.tone}');
    sb.writeln('Setting: ${state.seed.setting}');
    sb.writeln('Current scene: ${state.currentSceneDescription}');
    sb.writeln('Party position: ${state.partyPosition} on map ${state.currentMapId}');
    sb.writeln('World flags: ${state.worldFlags}');
    sb.writeln('Summary: ${state.runningSummary}');

    sb.writeln('\nTHE PARTY (stay true to each character\'s own persona — they are distinct individuals, not interchangeable heroes):');
    for (final m in state.party) {
      sb.writeln('- ${m.name} (${m.raceLabel} ${m.classLabel}, HP ${m.hp}/${m.maxHp}): ${m.persona}');
    }
    if (state.party.length > 1) {
      sb.writeln('\nOnly the first character listed above is directly controlled by the player. Every other party member is an AI-controlled companion — they are not silent followers: have them act on their own initiative each turn where it fits (a quip, a warning, drawing a weapon, covering a flank, disagreeing with the plan), in their own persona\'s voice, without waiting to be told what to do.');
    }
    if (addressedTo != null) {
      sb.writeln('\nThe player is speaking directly and specifically to $addressedTo, not to the whole party. Have $addressedTo respond personally, in their own voice, as the centerpiece of this reply. Other party members may still react briefly if it truly fits, but this exchange belongs to $addressedTo.');
    }

    sb.writeln('\nRecent turns:');
    for (final t in state.recentTurns.take(6)) {
      sb.writeln('Player: ${t.playerInput}');
      sb.writeln('DM: ${t.dmResponse}');
    }

    sb.writeln('\nAvailable actions — use the real rules, never invent a number yourself:');
    sb.writeln('  ability_check(character, ability, dc) — character is one of the party names above (or omit for the acting player); ability is STR/DEX/CON/INT/WIS/CHA; dc is the difficulty (10=easy, 15=moderate, 20=hard).');
    sb.writeln('  attack(character, target_ac, ability=STR|DEX, damage_die=6, damage_modifier=0) — target_ac is your best estimate of the target\'s armor class (10-18 typical).');
    sb.writeln('  roll_dice(sides, count, modifier) — for flavor rolls not tied to a character\'s stats.');
    sb.writeln('  update_hp(target, delta), add_item(target, item), move_party(x, y), move_companion(character, x, y) — moves one named companion on their own, separate from the party\'s shared position, trigger_encounter(id), advance_quest(id, stage).');
    sb.writeln('Emit exactly one <<ACTION: name key=val key2=val2>> line when the moment calls for a check, attack, or state change — the real dice will be rolled for you and the true result given back into the story. Otherwise, just narrate.');
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

  String? _resolveCharacterId(CampaignState state, String? nameOrId) {
    if (nameOrId == null) return null;
    for (final m in state.party) {
      if (m.characterId == nameOrId || m.name.toLowerCase() == nameOrId.toLowerCase()) return m.characterId;
    }
    return null;
  }

  /// Parses and applies whatever <<ACTION: ...>> the model emitted (if any),
  /// rolling the real dice via [tools] and returning the cleaned-up
  /// narration alongside whatever roll result happened — shared by both a
  /// normal player turn and a companion's own independent beat, so
  /// companions can genuinely roll checks, attack, pick things up, or
  /// advance a quest on their own, not just narrate flavor text.
  ({String narration, DiceResult? dice, CheckResult? check, AttackResult? attack}) _applyAction(String raw, CampaignState state, {String? fallbackInputForImpliedRoll}) {
    var narration = raw;
    DiceResult? diceResult;
    CheckResult? checkResult;
    AttackResult? attackResult;
    final action = DmTools.parseAction(raw);
    if (action != null) {
      final act = action['action']!;
      try {
        switch (act) {
          case 'ability_check':
            final charId = _resolveCharacterId(state, action['character']);
            final ability = action['ability'] ?? 'STR';
            final dc = int.tryParse(action['dc'] ?? '12') ?? 12;
            checkResult = tools.abilityCheck(state, characterId: charId, ability: ability, dc: dc);
            narration = DmTools.stripActionBlocks(raw);
            if (narration.isEmpty) {
              narration = checkResult.success ? 'The attempt succeeds!' : 'The attempt falls short...';
            }
            break;
          case 'attack':
            final charId = _resolveCharacterId(state, action['character']);
            final ability = action['ability'] ?? 'STR';
            final ac = int.tryParse(action['target_ac'] ?? '13') ?? 13;
            final dDie = int.tryParse(action['damage_die'] ?? '6') ?? 6;
            final dMod = int.tryParse(action['damage_modifier'] ?? '0') ?? 0;
            attackResult = tools.attackRoll(state, characterId: charId, ability: ability, targetAc: ac, damageDie: dDie, damageModifier: dMod);
            narration = DmTools.stripActionBlocks(raw);
            if (narration.isEmpty) {
              narration = attackResult.hit ? 'The blow lands!' : 'The attack misses!';
            }
            break;
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
          case 'move_companion':
            final who = action['character'];
            if (who != null) {
              final x = int.tryParse(action['x'] ?? '0') ?? state.partyPosition.x;
              final y = int.tryParse(action['y'] ?? '0') ?? state.partyPosition.y;
              tools.moveCompanion(state, who, Point(x, y));
            }
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
    } else if (fallbackInputForImpliedRoll != null) {
      // No action block from the model — if the input clearly called for a
      // check or attack, resolve one anyway using the real character sheet
      // rather than leaving the moment un-rolled. Uses the acting party
      // member's (first party member's) actual ability modifiers, never an
      // invented number.
      final lower = fallbackInputForImpliedRoll.toLowerCase();
      if (lower.contains('attack') || lower.contains('strike') || lower.contains('hit')) {
        attackResult = tools.attackRoll(state, ability: 'STR', targetAc: 13);
      } else if (lower.contains('roll') || lower.contains('check') || lower.contains('perception') || lower.contains('sneak') || lower.contains('persuade')) {
        checkResult = tools.abilityCheck(state, ability: 'WIS', dc: 12);
      }
      narration = DmTools.stripActionBlocks(narration);
      if (narration.trim().isEmpty) narration = raw;
    }

    // Strip any leaked action fragments just in case (safety filter from Phase 09)
    narration = narration.replaceAll(RegExp(r'<<ACTION:[^>]*>>?'), '').trim();
    return (narration: narration, dice: diceResult, check: checkResult, attack: attackResult);
  }

  Future<DmTurnResult> takeTurn({required String playerInput, required CampaignState state, void Function(String chunk)? onToken, String? addressedTo}) async {
    final prompt = _assemblePrompt(state, playerInput, addressedTo: addressedTo);
    final buffer = StringBuffer();
    await for (final chunk in model.generate(prompt, maxTokens: 512)) {
      buffer.write(chunk);
      onToken?.call(chunk);
    }
    final raw = buffer.toString();
    final applied = _applyAction(raw, state, fallbackInputForImpliedRoll: playerInput);
    var narration = applied.narration;
    if (narration.isEmpty) narration = 'The air hangs heavy as you consider your next move...';

    state.recentTurns = [
      ...state.recentTurns,
      TurnLogEntry(playerInput: playerInput, dmResponse: narration),
    ];
    if (narration.length > 200) {
      state.currentSceneDescription = narration.substring(0, 200);
    }
    _maybeSummarize(state);

    return DmTurnResult(narration: narration, updatedState: state, dice: applied.dice, check: applied.check, attack: applied.attack);
  }

  String _companionBeatPrompt(CampaignState state, PartyMemberStatus companion) {
    final sb = StringBuffer();
    sb.writeln('You are the Dungeon Master. This is NOT a reply to the player — it is an independent beat for one AI-controlled companion, acting entirely on their own initiative, completely unprompted.');
    sb.writeln('Campaign: ${state.seed.title} | Tone: ${state.seed.tone}');
    sb.writeln('Current scene: ${state.currentSceneDescription}');
    final activeQuest = state.questLog.where((q) => q.status == 'active').cast<QuestEntry?>().firstWhere((q) => true, orElse: () => null);
    if (activeQuest != null) sb.writeln('Active quest: ${activeQuest.title} (${activeQuest.stage})');
    sb.writeln('This companion: ${companion.name} (${companion.raceLabel} ${companion.classLabel}, HP ${companion.hp}/${companion.maxHp}): ${companion.persona}');
    sb.writeln('\n${companion.name} acts entirely on their own initiative right now — driven by their own persona and the active quest, not the player\'s input. This can be a real, mechanical action (searching something — emit ability_check; striking a nearby threat — emit attack; picking something up — emit add_item; pressing the quest forward — emit advance_quest) using the SAME action syntax the DM uses: exactly one <<ACTION: name key=val key2=val2>> line, using ${companion.name} as the character. Or it can be a smaller unprompted moment — a comment, a worry, investigating something — with no action line at all. Either way, write 1-2 short sentences in third person about ${companion.name} only. Never address the player directly, never narrate for anyone else, never break character.');
    sb.writeln('\nAvailable actions: ability_check(character, ability, dc), attack(character, target_ac, ability, damage_die, damage_modifier), add_item(character, item), advance_quest(quest_id, stage), move_companion(character, x, y).');
    sb.writeln('\n${companion.name}:');
    return sb.toString();
  }

  /// A companion acting entirely on their own, unprompted by any player
  /// input — a short, separate generation focused on just this one
  /// character's own persona (and the active quest), so the party doesn't
  /// feel like it's all waiting silently on the player between turns. Can
  /// emit a real action (a check, an attack, picking something up, pushing
  /// the quest forward) exactly like a normal turn, rolling real dice — not
  /// just flavor text. Returns null if nothing worth narrating came out.
  Future<DmTurnResult?> companionBeat({required CampaignState state, required PartyMemberStatus companion}) async {
    final prompt = _companionBeatPrompt(state, companion);
    final buffer = StringBuffer();
    await for (final chunk in model.generate(prompt, maxTokens: 140)) {
      buffer.write(chunk);
    }
    final raw = buffer.toString();
    final applied = _applyAction(raw, state);
    if (applied.narration.isEmpty) return null;
    state.recentTurns = [
      ...state.recentTurns,
      TurnLogEntry(playerInput: '(${companion.name} acts independently)', dmResponse: applied.narration),
    ];
    return DmTurnResult(narration: applied.narration, updatedState: state, dice: applied.dice, check: applied.check, attack: applied.attack);
  }
}
