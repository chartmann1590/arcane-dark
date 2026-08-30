import 'dart:math';
import 'campaign_state.dart';

class DiceResult {
  final List<int> rolls;
  final int modifier;
  final int total;
  const DiceResult(this.rolls, this.modifier, this.total);
  @override
  String toString() => '${rolls.join("+")} + $modifier = $total';
}

class DmTools {
  final Random _rng;
  DmTools({int? seed}) : _rng = Random(seed);

  DiceResult rollDice({required int sides, required int count, int modifier = 0}) {
    final rolls = List.generate(count, (_) => _rng.nextInt(sides) + 1);
    final total = rolls.fold(0, (a, b) => a + b) + modifier;
    return DiceResult(rolls, modifier, total);
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
