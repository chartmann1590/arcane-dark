import 'dart:math';
import 'ability_scores.dart';
import 'campaign_state.dart';

class DiceResult {
  final List<int> rolls;
  final int modifier;
  final int total;
  const DiceResult(this.rolls, this.modifier, this.total);
  @override
  String toString() => '${rolls.join("+")} + $modifier = $total';
}

/// A d20 ability check: real modifier pulled from the acting character's own
/// ability scores (not whatever number the model happens to type), compared
/// against a difficulty class. This is what makes "the rules" real instead of
/// cosmetic — the same DEX 14 rogue always gets the same +2 on a DEX check.
class CheckResult {
  final String ability;
  final int roll;
  final int modifier;
  final int total;
  final int dc;
  final bool success;
  final bool critical; // natural 20
  final bool fumble; // natural 1
  const CheckResult({required this.ability, required this.roll, required this.modifier, required this.total, required this.dc, required this.success, required this.critical, required this.fumble});
}

class AttackResult {
  final int roll;
  final int modifier;
  final int total;
  final int targetAc;
  final bool hit;
  final bool critical;
  final DiceResult? damage;
  const AttackResult({required this.roll, required this.modifier, required this.total, required this.targetAc, required this.hit, required this.critical, this.damage});
}

/// Standard 5e proficiency bonus by level (characters start at level 1).
int proficiencyBonusForLevel(int level) {
  if (level >= 17) return 6;
  if (level >= 13) return 5;
  if (level >= 9) return 4;
  if (level >= 5) return 3;
  return 2;
}

int abilityModifierByName(AbilityScores a, String ability) => switch (ability.toUpperCase()) {
      'STR' => a.strMod,
      'DEX' => a.dexMod,
      'CON' => a.conMod,
      'INT' => a.intMod,
      'WIS' => a.wisMod,
      'CHA' => a.chaMod,
      _ => 0,
    };

class DmTools {
  final Random _rng;
  DmTools({int? seed}) : _rng = Random(seed);

  DiceResult rollDice({required int sides, required int count, int modifier = 0}) {
    final rolls = List.generate(count, (_) => _rng.nextInt(sides) + 1);
    final total = rolls.fold(0, (a, b) => a + b) + modifier;
    return DiceResult(rolls, modifier, total);
  }

  PartyMemberStatus _resolveMember(CampaignState state, String? characterId) {
    if (characterId != null) {
      for (final m in state.party) {
        if (m.characterId == characterId || m.name.toLowerCase() == characterId.toLowerCase()) return m;
      }
    }
    return state.party.first;
  }

  /// d20 + real ability modifier vs a difficulty class. Natural 20 always
  /// succeeds, natural 1 always fails (standard 5e rule), regardless of DC.
  CheckResult abilityCheck(CampaignState state, {String? characterId, required String ability, required int dc}) {
    final member = _resolveMember(state, characterId);
    final mod = abilityModifierByName(member.abilities, ability);
    final roll = _rng.nextInt(20) + 1;
    final total = roll + mod;
    final critical = roll == 20;
    final fumble = roll == 1;
    return CheckResult(ability: ability.toUpperCase(), roll: roll, modifier: mod, total: total, dc: dc, success: critical || (!fumble && total >= dc), critical: critical, fumble: fumble);
  }

  /// d20 + ability modifier + proficiency bonus vs target AC. On a hit, rolls
  /// damage too (doubled dice on a natural 20, per 5e crit rules) so the
  /// narration always has a real number to point to, not an invented one.
  AttackResult attackRoll(CampaignState state, {String? characterId, String ability = 'STR', required int targetAc, int damageDie = 6, int damageModifier = 0}) {
    final member = _resolveMember(state, characterId);
    final mod = abilityModifierByName(member.abilities, ability) + proficiencyBonusForLevel(1);
    final roll = _rng.nextInt(20) + 1;
    final total = roll + mod;
    final critical = roll == 20;
    final hit = critical || total >= targetAc;
    DiceResult? damage;
    if (hit) {
      damage = rollDice(sides: damageDie, count: critical ? 2 : 1, modifier: damageModifier);
    }
    return AttackResult(roll: roll, modifier: mod, total: total, targetAc: targetAc, hit: hit, critical: critical, damage: damage);
  }

  void updateHp(CampaignState state, String targetId, int delta) {
    for (final m in state.party) {
      if (m.characterId == targetId) {
        m.hp = (m.hp + delta).clamp(0, m.maxHp);
        if (delta < 0) {
          state.worldFlags['lastDamage'] = -delta;
        }
      }
    }
  }

  void addItem(CampaignState state, String targetId, String item) {
    for (final m in state.party) {
      if (m.characterId == targetId) {
        m.inventory = [...m.inventory, item];
      }
    }
  }

  void moveParty(CampaignState state, Point destination) {
    state.partyPosition = destination;
    state.visitedTiles.add('${destination.x},${destination.y}');
  }

  /// Places one named companion at their own tile, independent of the
  /// party's shared position — for when the DM narrates someone stepping
  /// away on their own (guarding a door, scouting ahead, fleeing danger).
  void moveCompanion(CampaignState state, String characterNameOrId, Point destination) {
    for (final m in state.party) {
      if (m.characterId == characterNameOrId || m.name.toLowerCase() == characterNameOrId.toLowerCase()) {
        m.position = destination;
        state.visitedTiles.add('${destination.x},${destination.y}');
        return;
      }
    }
  }

  void triggerEncounter(CampaignState state, String encounterId) {
    state.worldFlags['encounter:$encounterId'] = true;
    state.worldFlags['lastEncounter'] = encounterId;
  }

  void advanceQuest(CampaignState state, String questId, String stage) {
    for (final q in state.questLog) {
      if (q.id == questId) {
        // mutate via copy: for simplicity replace list entry
        final idx = state.questLog.indexOf(q);
        state.questLog[idx] = QuestEntry(id: q.id, title: q.title, stage: stage, status: stage == 'completed' ? 'completed' : 'active');
      }
    }
  }

  // Parser for model output — rigid template not JSON
  // Expected: <<ACTION: roll_dice sides=20 count=1 modifier=3>>
  static Map<String, String>? parseAction(String text) {
    final re = RegExp(r'<<ACTION:\s*(\w+)(.*?)>>');
    final m = re.firstMatch(text);
    if (m == null) return null;
    final action = m.group(1)!;
    final paramsStr = m.group(2) ?? '';
    final params = <String, String>{'action': action};
    final kvRe = RegExp(r'(\w+)=("[^"]*"|\S+)');
    for (final kv in kvRe.allMatches(paramsStr)) {
      var v = kv.group(2)!;
      if (v.startsWith('"') && v.endsWith('"')) v = v.substring(1, v.length - 1);
      params[kv.group(1)!] = v;
    }
    return params;
  }

  static String stripActionBlocks(String text) {
    return text.replaceAll(RegExp(r'<<ACTION:.*?>>'), '').trim();
  }
}
