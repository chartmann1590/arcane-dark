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
    sb.writeln('You are a tabletop Dungeon Master. Narrate in second person, in-character, never break 4th wall.');
    sb.writeln('Campaign: ${state.seed.title} (${state.seed.setting}) | Scene: ${state.currentSceneDescription}');
    sb.writeln('Party position: ${state.partyPosition} on map ${state.currentMapId}');
    sb.writeln('Exploration Progress: ${state.visitedTiles.length} tiles uncovered, ${state.openedDoors.length} doors opened, ${state.defeatedEnemies.length} enemies defeated, Dungeon Depth: ${state.worldFlags["dungeonDepth"] ?? 1}.');
    sb.writeln('STRICT RULE: The party is actively exploring an isometric dungeon map. The player MUST physically walk corridors, unlock doors, disarm traps, and reach chamber targets on the map. The player CANNOT defeat distant bosses, loot far-away rooms, or finish campaign beats through chat alone from a distance without navigating the map first.');

    final cleanFlags = Map<String, dynamic>.from(state.worldFlags)
      ..remove('openedDoors')
      ..remove('defeatedEnemies')
      ..remove('visitedTiles');
    if (cleanFlags.isNotEmpty) {
      sb.writeln('Flags: $cleanFlags');
    }
    if (state.runningSummary.isNotEmpty) {
      final sum = state.runningSummary.length > 200
          ? '...${state.runningSummary.substring(state.runningSummary.length - 200)}'
          : state.runningSummary;
      sb.writeln('Summary: $sum');
    }

    sb.writeln('\nTHE PARTY:');
    for (final m in state.party) {
      sb.writeln('- ${m.name} (${m.raceLabel} ${m.classLabel}, HP ${m.hp}/${m.maxHp}): ${m.persona}');
    }
    if (state.party.length > 1) {
      sb.writeln('First character is player; other party members are autonomous AI companions who speak and react on their own.');
    }
    if (addressedTo != null) {
      sb.writeln('\nPlayer speaks directly to $addressedTo. $addressedTo must reply in their persona.');
    }

    final recent = state.recentTurns.length > 3
        ? state.recentTurns.sublist(state.recentTurns.length - 3)
        : state.recentTurns;
    if (recent.isNotEmpty) {
      sb.writeln('\nRecent history:');
      for (final t in recent) {
        final shortDm = t.dmResponse.length > 120 ? '${t.dmResponse.substring(0, 120)}...' : t.dmResponse;
        sb.writeln('Player: ${t.playerInput}');
        sb.writeln('DM: $shortDm');
      }
    }

    sb.writeln('\nAction syntax (emit max 1 <<ACTION: ...>> line if roll/update needed):');
    sb.writeln('  ability_check(character, ability, dc), attack(character, target_ac, ability, damage_die, damage_modifier), roll_dice(sides, count, modifier), update_hp(target, delta), add_item(target, item), move_companion(character, x, y).');
    sb.writeln('\nPlayer says: $playerInput');
    sb.writeln('Respond as DM in 2-3 immersive sentences:');
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
    bool generatedSuccessfully = false;

    try {
      await for (final chunk in model.generate(prompt, maxTokens: 140)) {
        buffer.write(chunk);
        onToken?.call(chunk);
      }
      if (buffer.isNotEmpty) {
        generatedSuccessfully = true;
      }
    } catch (_) {
      generatedSuccessfully = false;
    }

    if (!generatedSuccessfully || buffer.toString().trim().isEmpty) {
      return _generateProceduralTurn(
        state: state,
        playerInput: playerInput,
        addressedTo: addressedTo,
        onToken: onToken,
      );
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

  Future<DmTurnResult> _generateProceduralTurn({
    required CampaignState state,
    required String playerInput,
    String? addressedTo,
    void Function(String chunk)? onToken,
  }) async {
    final lower = playerInput.toLowerCase();
    final actingHero = state.party.isNotEmpty ? state.party.first : null;
    final heroName = actingHero?.name ?? 'You';
    final rng = Random();

    DiceResult? diceResult;
    CheckResult? checkResult;
    AttackResult? attackResult;
    String narration;

    if (addressedTo != null) {
      // Direct conversation with companion
      final comp = state.party.firstWhere(
        (m) => m.name.toLowerCase() == addressedTo.toLowerCase(),
        orElse: () => state.party.length > 1 ? state.party[1] : state.party.first,
      );
      final persona = comp.persona.toLowerCase();
      final classLower = comp.classLabel.toLowerCase();

      String speech;
      if (classLower.contains('fighter') || classLower.contains('barbarian') || persona.contains('gruff') || persona.contains('dwarf')) {
        final quotes = [
          '${comp.name} nods firmly, adjusting their grip on their weapon. "Aye, you have my steel. Let\'s see what this dungeon throws at us next."',
          '${comp.name} grunts with a stoic grin. "Keep your shield high and watch the dark corners. We finish this together."',
          '${comp.name} gestures forward with a battle-scarred gauntlet. "Lead on. Whatever lurks here won\'t survive our blade."',
        ];
        speech = quotes[rng.nextInt(quotes.length)];
      } else if (classLower.contains('rogue') || persona.contains('sneaky') || persona.contains('cunning') || persona.contains('elf')) {
        final quotes = [
          '${comp.name} twirls a curved dagger with effortless grace. "Stay low and quiet. I\'m keeping watch on the shadows behind us."',
          '${comp.name} smirks faintly, listening to the echoing stones. "Two steps ahead of you. No tripwires or ambushers within earshot... yet."',
          '${comp.name} dips into the gloom at your flank. "You make the opening, and I\'ll strike from the blind spot."',
        ];
        speech = quotes[rng.nextInt(quotes.length)];
      } else if (classLower.contains('wizard') || classLower.contains('sorcerer') || persona.contains('scholar') || persona.contains('arcane')) {
        final quotes = [
          '${comp.name} adjusts their spellbook, arcane sparks dancing at their fingertips. "The ambient weave here is unstable, but my spells are primed for when you give the word."',
          '${comp.name} peers closely at the stone runes. "Fascinating history here. Proceed with caution — ancient wardings don\'t fade easily."',
          '${comp.name} nods thoughtfully. "I\'ll hold the incantation until you need heavy arcane support."',
        ];
        speech = quotes[rng.nextInt(quotes.length)];
      } else {
        final quotes = [
          '${comp.name} turns to you with unwavering resolve. "With you until the end, $heroName. Tell me where you need me."',
          '${comp.name} checks their gear and nods. "Ready when you are. Let us press forward."',
        ];
        speech = quotes[rng.nextInt(quotes.length)];
      }
      narration = speech;
    } else if (lower.contains('attack') || lower.contains('strike') || lower.contains('swing') || lower.contains('slash') || lower.contains('stab') || lower.contains('shoot') || lower.contains('cast') || lower.contains('smite')) {
      // Combat attack
      final ability = (actingHero?.classLabel.toLowerCase().contains('rogue') ?? false) ? 'DEX' : 'STR';
      attackResult = tools.attackRoll(state, characterId: actingHero?.characterId, ability: ability, targetAc: 13, damageDie: 8);

      final companionReaction = state.party.length > 1
          ? ' ${state.party[1].name} braces to cover your flank.'
          : '';

      if (attackResult.critical) {
        narration = 'NATURAL 20! With lightning speed, $heroName delivers a devastating strike! Steel meets foe with a thunderous crunch, dealing ${attackResult.damage?.total ?? 14} damage as sparks light up the chamber!$companionReaction';
      } else if (attackResult.hit) {
        narration = 'Your weapon flashes through the shadows! The blow connects squarely, inflicting ${attackResult.damage?.total ?? 7} damage against your target.$companionReaction';
      } else {
        narration = 'You lunge forward with all your strength, but the foe dodges beneath your guard, the strike scraping harmlessly across stone.$companionReaction';
      }
    } else if (lower.contains('search') || lower.contains('investigate') || lower.contains('inspect') || lower.contains('look') || lower.contains('examine') || lower.contains('scan') || lower.contains('perception')) {
      // Skill check: Investigation / Perception
      checkResult = tools.abilityCheck(state, characterId: actingHero?.characterId, ability: 'WIS', dc: 12);
      if (checkResult.critical) {
        narration = 'NATURAL 20! Your senses are razor sharp. You discern every subtle draft, ancient chisel mark, and the faint glimmer of concealed treasure buried under the rubble!';
      } else if (checkResult.success) {
        narration = 'You carefully scrutinize your surroundings (Perception succeeded). You spot undisturbed masonry, faint footprints in the damp dust, and confirm the path ahead is clear of immediate ambushes.';
      } else {
        narration = 'You scan the gloomy perimeter, but dense cobwebs and shifting torch shadows make it difficult to spot anything beyond the cold stonework.';
      }
    } else if (lower.contains('sneak') || lower.contains('stealth') || lower.contains('hide')) {
      // Stealth check
      checkResult = tools.abilityCheck(state, characterId: actingHero?.characterId, ability: 'DEX', dc: 12);
      if (checkResult.success) {
        narration = 'You melt into the darkness (Stealth succeeded). Your footsteps make not a sound against the mossy flagstones as you observe undetected.';
      } else {
        narration = 'You attempt to tread quietly, but a loose shard of slate clatters across the floor, echoing faintly through the corridor.';
      }
    } else if (lower.contains('rest') || lower.contains('camp') || lower.contains('heal') || lower.contains('potion')) {
      narration = 'The party pauses in the shadow of the stone arches to catch their breath and dress their wounds. Warm torchlight keeps the encroaching shadows at bay.';
    } else {
      // General narrative exploration
      final scenes = [
        'The air grows cooler as you advance. Water drips rhythmically from vaulted stone arches, and the party stays alert with weapons at the ready.',
        'Dust motes dance in the flickering torchlight. Ancient carvings along the stone walls hint at forgotten kings and forgotten crypts.',
        'You step forward over worn flagstones. Every sound echoes softly in the vast subterranean stillness as your companions keep watch.',
      ];
      narration = scenes[rng.nextInt(scenes.length)];
      if (state.party.length > 1 && rng.nextBool()) {
        narration += ' ${state.party[1].name} scans the darkness ahead with weapon drawn.';
      }
    }

    // Stream the narration smoothly in chunks
    final words = narration.split(' ');
    for (var i = 0; i < words.length; i++) {
      final chunk = i == 0 ? words[i] : ' ${words[i]}';
      onToken?.call(chunk);
    }

    state.recentTurns = [
      ...state.recentTurns,
      TurnLogEntry(playerInput: playerInput, dmResponse: narration),
    ];
    if (narration.length > 200) {
      state.currentSceneDescription = narration.substring(0, 200);
    }
    _maybeSummarize(state);

    return DmTurnResult(
      narration: narration,
      updatedState: state,
      dice: diceResult,
      check: checkResult,
      attack: attackResult,
    );
  }

  String _companionBeatPrompt(CampaignState state, PartyMemberStatus companion) {
    final sb = StringBuffer();
    sb.writeln('You are the Dungeon Master. Independent beat for AI companion ${companion.name}, acting on their own initiative.');
    sb.writeln('Campaign: ${state.seed.title} | Tone: ${state.seed.tone} | Scene: ${state.currentSceneDescription}');
    final activeQuest = state.questLog.where((q) => q.status == 'active').cast<QuestEntry?>().firstWhere((q) => true, orElse: () => null);
    if (activeQuest != null) sb.writeln('Active quest: ${activeQuest.title} (${activeQuest.stage})');
    sb.writeln('Companion: ${companion.name} (${companion.raceLabel} ${companion.classLabel}, HP ${companion.hp}/${companion.maxHp}): ${companion.persona}');
    sb.writeln('\nWrite 1-2 short sentences in 3rd person about ${companion.name} acting independently. Can optionally emit: <<ACTION: ability_check|attack|add_item|move_companion ...>>.');
    sb.writeln('\n${companion.name}:');
    return sb.toString();
  }

  String _proceduralCompanionBeatText(CampaignState state, PartyMemberStatus companion) {
    final rng = Random();
    final cName = companion.name;
    final persona = companion.persona.toLowerCase();
    final classLabel = companion.classLabel.toLowerCase();

    if (classLabel.contains('rogue') || persona.contains('sneaky') || persona.contains('scout')) {
      final beats = [
        '$cName quietly checks the seam of the floor ahead for hidden tripwires, murmuring: "Nothing rigged here. Safe to tread."',
        '$cName peers into the darkness with a keen gaze, hand resting lightly on their quiver. "Shadows are quiet... for now."',
      ];
      return beats[rng.nextInt(beats.length)];
    } else if (classLabel.contains('fighter') || classLabel.contains('barbarian') || persona.contains('dwarf') || persona.contains('warrior')) {
      final beats = [
        '$cName tests the weight of their weapon and rolls their shoulders. "Whatever waits behind the next door won\'t catch us unprepared."',
        '$cName inspects a gouge mark in the wall. "Old battle scars in the stone. Keep your guard up."',
      ];
      return beats[rng.nextInt(beats.length)];
    } else if (classLabel.contains('wizard') || classLabel.contains('mage') || classLabel.contains('sorcerer')) {
      final beats = [
        '$cName closes their eyes for a second, sensing the ambient magical currents in the chamber. "The weave is steady here."',
        '$cName jots a quick arcane glyph into their personal notes, nodding to the party.',
      ];
      return beats[rng.nextInt(beats.length)];
    } else {
      final beats = [
        '$cName surveys the perimeter with a calm nod. "All clear on this flank."',
        '$cName whispers a quiet prayer for protection, a brief golden warmth steadying the party.',
      ];
      return beats[rng.nextInt(beats.length)];
    }
  }

  Future<DmTurnResult?> companionBeat({required CampaignState state, required PartyMemberStatus companion}) async {
    final prompt = _companionBeatPrompt(state, companion);
    final buffer = StringBuffer();
    try {
      await for (final chunk in model.generate(prompt, maxTokens: 100)) {
        buffer.write(chunk);
      }
    } catch (_) {
      // Model error or timeout — seamless procedural fallback
    }
    var raw = buffer.toString().trim();
    if (raw.isEmpty) {
      raw = _proceduralCompanionBeatText(state, companion);
    }
    final applied = _applyAction(raw, state);
    if (applied.narration.isEmpty) return null;
    state.recentTurns = [
      ...state.recentTurns,
      TurnLogEntry(playerInput: '(${companion.name} acts independently)', dmResponse: applied.narration),
    ];
    return DmTurnResult(narration: applied.narration, updatedState: state, dice: applied.dice, check: applied.check, attack: applied.attack);
  }
}
