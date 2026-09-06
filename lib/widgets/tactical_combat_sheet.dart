import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../domain/campaign_state.dart';
import '../domain/pet_companion.dart';
import '../features/play/tavern_populator.dart';
import '../services/audio_service.dart';
import '../services/tv_cast_service.dart';
import 'fx.dart';

enum StatusType {
  burning,
  poisoned,
  stunned,
  shielded,
  enraged,
  blessed,
}

class CombatStatusEffect {
  final StatusType type;
  int remainingRounds;
  final int magnitude;

  CombatStatusEffect({
    required this.type,
    this.remainingRounds = 2,
    this.magnitude = 2,
  });

  String get icon => switch (type) {
        StatusType.burning => '🔥',
        StatusType.poisoned => '🧪',
        StatusType.stunned => '⚡',
        StatusType.shielded => '🛡️',
        StatusType.enraged => '💢',
        StatusType.blessed => '✨',
      };

  String get label => switch (type) {
        StatusType.burning => 'Burning',
        StatusType.poisoned => 'Poisoned',
        StatusType.stunned => 'Stunned',
        StatusType.shielded => 'Shielded',
        StatusType.enraged => 'Enraged',
        StatusType.blessed => 'Blessed',
      };

  Color get color => switch (type) {
        StatusType.burning => Colors.orangeAccent,
        StatusType.poisoned => Colors.greenAccent,
        StatusType.stunned => Colors.amberAccent,
        StatusType.shielded => Colors.blueAccent,
        StatusType.enraged => Colors.redAccent,
        StatusType.blessed => Colors.cyanAccent,
      };
}

class Combatant {
  final String id;
  final String name;
  final String role;
  final String portraitAsset;
  final bool isPlayer;
  final bool isCompanion;
  final bool isEnemy;
  int initiative;
  int currentHp;
  int maxHp;
  int armorClass;
  int attackBonus;
  int damageDice;
  String attackName;
  final PartyMemberStatus? partyMember;
  bool isDefending;
  final List<CombatStatusEffect> statuses = [];

  Combatant({
    required this.id,
    required this.name,
    required this.role,
    required this.portraitAsset,
    this.isPlayer = false,
    this.isCompanion = false,
    this.isEnemy = false,
    this.initiative = 10,
    required this.currentHp,
    required this.maxHp,
    this.armorClass = 12,
    this.attackBonus = 3,
    this.damageDice = 6,
    this.attackName = 'Strike',
    this.partyMember,
    this.isDefending = false,
  });

  bool get isStunned => statuses.any((s) => s.type == StatusType.stunned);
  bool get isShielded => statuses.any((s) => s.type == StatusType.shielded);
  bool get isEnraged => statuses.any((s) => s.type == StatusType.enraged);
  bool get isBurning => statuses.any((s) => s.type == StatusType.burning);
  bool get isPoisoned => statuses.any((s) => s.type == StatusType.poisoned);
  bool get isBlessed => statuses.any((s) => s.type == StatusType.blessed);

  void addStatus(StatusType type, {int rounds = 2, int magnitude = 2}) {
    statuses.removeWhere((s) => s.type == type);
    statuses.add(CombatStatusEffect(type: type, remainingRounds: rounds, magnitude: magnitude));
  }

  void removeStatus(StatusType type) {
    statuses.removeWhere((s) => s.type == type);
  }
}

class TacticalCombatSheet extends StatefulWidget {
  final MapNpc initialEnemy;
  final CampaignState campaign;
  final PetCompanion? activePet;
  final void Function(MapNpc updatedEnemy) onEnemyUpdated;
  final void Function(MapNpc defeatedEnemy) onEnemyDefeated;
  final void Function(String characterId, int damage) onHeroDamaged;
  final void Function(String combatNarration) onCombatNarration;

  const TacticalCombatSheet({
    super.key,
    required this.initialEnemy,
    required this.campaign,
    this.activePet,
    required this.onEnemyUpdated,
    required this.onEnemyDefeated,
    required this.onHeroDamaged,
    required this.onCombatNarration,
  });

  @override
  State<TacticalCombatSheet> createState() => _TacticalCombatSheetState();
}

class _TacticalCombatSheetState extends State<TacticalCombatSheet> with SingleTickerProviderStateMixin {
  late MapNpc _enemyNpc;
  final List<Combatant> _combatants = [];
  int _currentTurnIndex = 0;
  int _roundNumber = 1;
  final List<String> _battleLog = [];
  bool _isActing = false;
  bool _autoBattle = false;
  String? _bannerText;
  Color _bannerColor = Colors.amber;
  Timer? _aiTurnTimer;

  // Floating damage / heal text effects
  String? _floatingEnemyText;
  Color _floatingEnemyColor = Colors.redAccent;
  final Map<String, String> _floatingPartyTexts = {};
  String? _telegraphedEnemyIntent;
  String? _lastComboActor;

  void _broadcastCombatState({bool active = true}) {
    TvCastService.instance.broadcastCombat({
      'active': active,
      'round': _roundNumber,
      'intent': _telegraphedEnemyIntent ?? '⚠️ ENEMY INTENT: Aggressive Assault',
      'enemyName': _enemyNpc.name,
      'enemyRole': _enemyNpc.role,
      'enemyAc': _enemyNpc.armorClass,
      'enemyHp': max(0, _enemyNpc.currentHp),
      'enemyMaxHp': _enemyNpc.maxHp,
      'logs': _battleLog.take(15).toList(),
    });
  }

  @override
  void initState() {
    super.initState();
    _enemyNpc = widget.initialEnemy;
    _setupCombatants();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _broadcastCombatState();
    });
  }

  @override
  void dispose() {
    _aiTurnTimer?.cancel();
    _broadcastCombatState(active: false);
    super.dispose();
  }

  void _setupCombatants() {
    final rng = Random();
    final party = widget.campaign.party;

    // 1. Add Player Hero (first party member)
    if (party.isNotEmpty) {
      final playerHero = party.first;
      final dexMod = playerHero.abilities.dexMod;
      final init = rng.nextInt(20) + 1 + dexMod;
      _combatants.add(
        Combatant(
          id: playerHero.characterId,
          name: playerHero.name,
          role: playerHero.classLabel,
          portraitAsset: 'assets/avatar/portraits/human.png',
          isPlayer: true,
          initiative: init,
          currentHp: playerHero.hp,
          maxHp: playerHero.maxHp,
          armorClass: playerHero.armorClass,
          attackBonus: max(playerHero.abilities.strMod, dexMod) + 2,
          damageDice: playerHero.classLabel.toLowerCase().contains('rogue') ? 6 : 8,
          attackName: 'Melee Strike',
          partyMember: playerHero,
        ),
      );
    } else {
      _combatants.add(
        Combatant(
          id: 'hero',
          name: 'Hero',
          role: 'Fighter',
          portraitAsset: 'assets/avatar/portraits/human.png',
          isPlayer: true,
          initiative: rng.nextInt(20) + 1 + 2,
          currentHp: 20,
          maxHp: 20,
          armorClass: 14,
          attackBonus: 4,
          damageDice: 8,
          attackName: 'Longsword Strike',
        ),
      );
    }

    // 2. Add AI Companions (skip first member which is the player)
    for (var i = 1; i < party.length; i++) {
      final comp = party[i];
      final dexMod = comp.abilities.dexMod;
      final init = rng.nextInt(20) + 1 + dexMod;
      final portrait = comp.raceLabel.toLowerCase().contains('elf')
          ? 'assets/avatar/portraits/elf.png'
          : comp.raceLabel.toLowerCase().contains('dwarf')
              ? 'assets/avatar/portraits/dwarf.png'
              : comp.raceLabel.toLowerCase().contains('halfling')
                  ? 'assets/avatar/portraits/halfling.png'
                  : 'assets/avatar/portraits/tiefling.png';

      _combatants.add(
        Combatant(
          id: comp.characterId,
          name: comp.name,
          role: comp.classLabel,
          portraitAsset: portrait,
          isCompanion: true,
          initiative: init,
          currentHp: comp.hp,
          maxHp: comp.maxHp,
          armorClass: comp.armorClass,
          attackBonus: max(comp.abilities.strMod, dexMod) + 2,
          damageDice: comp.classLabel.toLowerCase().contains('wizard') ? 10 : 8,
          attackName: comp.classLabel.toLowerCase().contains('wizard') ? 'Arcane Bolt' : 'Flank Attack',
          partyMember: comp,
        ),
      );
    }

    // 3. Add Enemy
    final enemyInit = rng.nextInt(20) + 1 + max(0, _enemyNpc.attackBonus - 2).toInt();
    _combatants.add(
      Combatant(
        id: _enemyNpc.id,
        name: _enemyNpc.name,
        role: _enemyNpc.role,
        portraitAsset: _enemyNpc.portraitAsset,
        isEnemy: true,
        initiative: enemyInit,
        currentHp: _enemyNpc.currentHp,
        maxHp: _enemyNpc.maxHp,
        armorClass: _enemyNpc.armorClass,
        attackBonus: _enemyNpc.attackBonus,
        damageDice: _enemyNpc.damageDice,
        attackName: _enemyNpc.attackName,
      ),
    );

    // Sort descending by initiative
    _combatants.sort((a, b) => b.initiative.compareTo(a.initiative));

    _battleLog.add('⚔️ Round 1 initiated! Turn order established.');
    for (final c in _combatants) {
      _battleLog.add('• ${c.name} (Init: ${c.initiative})');
    }
    _prepareNextEnemyIntent();

    // Check if the first combatant is an AI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTriggerAiTurn();
    });
  }

  void _prepareNextEnemyIntent() {
    final enemy = _enemyCombatant;
    if (enemy == null || enemy.currentHp <= 0) {
      _telegraphedEnemyIntent = null;
      return;
    }

    final role = enemy.role.toLowerCase();
    final name = enemy.name.toLowerCase();

    if (role.contains('caster') || role.contains('shadow') || name.contains('cultist') || name.contains('wraith')) {
      if (enemy.currentHp < enemy.maxHp * 0.6) {
        _telegraphedEnemyIntent = '🔮 Dark Siphon (Leeching Life)';
      } else {
        _telegraphedEnemyIntent = '💀 Shadow Curse (Inflicts Poison)';
      }
    } else if (role.contains('sentry') || role.contains('guardian') || name.contains('skeleton') || name.contains('golem')) {
      if (!enemy.isShielded && enemy.currentHp < enemy.maxHp * 0.7) {
        _telegraphedEnemyIntent = '🛡️ Phalanx Bulwark (+4 AC & Guard)';
      } else {
        _telegraphedEnemyIntent = '⚡ Heavy Shield Slam (Chance to Stun)';
      }
    } else if (role.contains('brute') || role.contains('berserker') || name.contains('orc')) {
      if (enemy.currentHp < enemy.maxHp * 0.5 && !enemy.isEnraged) {
        _telegraphedEnemyIntent = '💢 Building Blood Frenzy (Enrage imminent!)';
      } else {
        _telegraphedEnemyIntent = '🪓 Reckless Cleave (Heavy damage windup)';
      }
    } else if (role.contains('raider') || role.contains('skulker') || name.contains('goblin')) {
      _telegraphedEnemyIntent = '🧪 Dipping Blade in Venom (Poison Ambush)';
    } else {
      _telegraphedEnemyIntent = '⚔️ Aggressive Strike (Direct assault)';
    }
  }

  Combatant get _activeCombatant {
    if (_combatants.isEmpty) {
      return Combatant(id: 'none', name: 'None', role: '', portraitAsset: '', currentHp: 0, maxHp: 1);
    }
    return _combatants[_currentTurnIndex.clamp(0, _combatants.length - 1)];
  }

  Combatant? get _enemyCombatant {
    return _combatants.where((c) => c.isEnemy).firstOrNull;
  }

  List<Combatant> get _partyCombatants {
    return _combatants.where((c) => c.isPlayer || c.isCompanion).toList();
  }

  void _checkTriggerAiTurn() {
    if (_isActing) return;
    final active = _activeCombatant;
    final enemy = _enemyCombatant;
    if (enemy == null || enemy.currentHp <= 0) return;

    if (active.isEnemy) {
      _aiTurnTimer?.cancel();
      _aiTurnTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) _executeEnemyTurn();
      });
    } else if (active.isCompanion) {
      _aiTurnTimer?.cancel();
      _aiTurnTimer = Timer(const Duration(milliseconds: 750), () {
        if (mounted) _executeCompanionTurn(active);
      });
    } else if (active.isPlayer && _autoBattle) {
      _aiTurnTimer?.cancel();
      _aiTurnTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) _executeMeleeAttack();
      });
    }
  }

  void _advanceTurn() async {
    final enemy = _enemyCombatant;
    if (enemy == null || enemy.currentHp <= 0) return;

    // Remove defending stance from previous combatant
    _activeCombatant.isDefending = false;

    int nextIdx = (_currentTurnIndex + 1) % _combatants.length;
    if (nextIdx == 0) {
      _roundNumber++;
      _battleLog.insert(0, '⚔️ --- ROUND $_roundNumber ---');
      _prepareNextEnemyIntent();
    }

    final nextCombatant = _combatants[nextIdx];

    // Status effect ticks at turn start:
    // 1. Burning tick
    if (nextCombatant.isBurning && nextCombatant.currentHp > 0) {
      const burnDmg = 2;
      nextCombatant.currentHp = max(0, nextCombatant.currentHp - burnDmg);
      if (nextCombatant.isEnemy) {
        _enemyNpc = _enemyNpc.copyWith(currentHp: nextCombatant.currentHp);
        widget.onEnemyUpdated(_enemyNpc);
        _floatingEnemyText = '-$burnDmg 🔥';
        _floatingEnemyColor = Colors.orangeAccent;
      } else {
        _floatingPartyTexts[nextCombatant.id] = '-$burnDmg 🔥';
        if (nextCombatant.partyMember != null) {
          widget.onHeroDamaged(nextCombatant.id, burnDmg);
        }
      }
      _battleLog.insert(0, '🔥 ${nextCombatant.name} takes $burnDmg fire damage from burning!');
      if (nextCombatant.isEnemy && nextCombatant.currentHp <= 0) {
        _handleVictory('Lingering flames');
        return;
      }
    }

    // 2. Poison tick
    if (nextCombatant.isPoisoned && nextCombatant.currentHp > 0) {
      const poisonDmg = 2;
      nextCombatant.currentHp = max(0, nextCombatant.currentHp - poisonDmg);
      if (nextCombatant.isEnemy) {
        _enemyNpc = _enemyNpc.copyWith(currentHp: nextCombatant.currentHp);
        widget.onEnemyUpdated(_enemyNpc);
        _floatingEnemyText = '-$poisonDmg 🧪';
        _floatingEnemyColor = Colors.greenAccent;
      } else {
        _floatingPartyTexts[nextCombatant.id] = '-$poisonDmg 🧪';
        if (nextCombatant.partyMember != null) {
          widget.onHeroDamaged(nextCombatant.id, poisonDmg);
        }
      }
      _battleLog.insert(0, '🧪 ${nextCombatant.name} suffers $poisonDmg poison damage!');
      if (nextCombatant.isEnemy && nextCombatant.currentHp <= 0) {
        _handleVictory('Deadly poison');
        return;
      }
    }

    // Decrement status effect durations and remove expired
    for (var i = nextCombatant.statuses.length - 1; i >= 0; i--) {
      final st = nextCombatant.statuses[i];
      st.remainingRounds--;
      if (st.remainingRounds <= 0) {
        nextCombatant.statuses.removeAt(i);
        _battleLog.insert(0, '✨ ${nextCombatant.name} recovered from ${st.label}.');
      }
    }

    // 3. Stun check: skips action
    if (nextCombatant.isStunned) {
      setState(() {
        _currentTurnIndex = nextIdx;
        _bannerText = '⚡ ${nextCombatant.name} is STUNNED and reels, skipping turn!';
        _bannerColor = Colors.amberAccent;
        _battleLog.insert(0, '⚡ ${nextCombatant.name} is stunned and unable to act this turn!');
      });
      AudioService.instance.playError();
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _advanceTurn();
      return;
    }

    setState(() {
      _currentTurnIndex = nextIdx;
      _isActing = false;
    });

    _broadcastCombatState();
    _checkTriggerAiTurn();
  }

  // --- PLAYER ACTIONS ---

  Future<void> _executeMeleeAttack() async {
    final enemy = _enemyCombatant;
    if (_isActing || enemy == null || enemy.currentHp <= 0) return;
    final hero = _activeCombatant;

    setState(() {
      _isActing = true;
      _bannerText = null;
    });

    AudioService.instance.playDiceRoll();
    final d20 = Random().nextInt(20) + 1;
    final totalAtk = d20 + hero.attackBonus;
    final isCrit = d20 == 20;
    final isHit = isCrit || (d20 > 1 && totalAtk >= enemy.armorClass);

    TvCastService.instance.broadcastDiceRoll(
      roller: hero.name,
      reason: isHit ? 'Melee Strike (HIT)' : 'Melee Strike (MISS)',
      d20: d20,
      modifier: hero.attackBonus,
      total: totalAtk,
    );

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (isHit) {
      AudioService.instance.playSend();
      var dmg = Random().nextInt(hero.damageDice) + 1 + max(1, hero.attackBonus - 2);
      if (isCrit) dmg *= 2;

      // Active pet companion perk bonuses
      final pet = widget.activePet;
      if (pet != null && pet.id != 'none') {
        if (pet.id == 'shadow_wolf' && isCrit) {
          dmg += 2;
          _battleLog.insert(0, '🐺 Shadow Wolf pack instinct (+2 Crit DMG)!');
        } else if (pet.id == 'pygmy_drake') {
          dmg += 2;
          _battleLog.insert(0, '🐉 Pygmy Drake breathes embers (+2 Fire DMG)!');
        } else if (pet.id == 'tavern_hound') {
          _battleLog.insert(0, '🐕 Tavern Hound distracts ${enemy.name}!');
        } else if (pet.id == 'astral_falcon') {
          _battleLog.insert(0, '🦅 Astral Falcon harries ${enemy.name} from above!');
        }
      }

      // Combo Stagger bonus when alternating party attacks
      if (_lastComboActor != null && _lastComboActor != hero.id) {
        dmg += 3;
        _battleLog.insert(0, '⚡ COMBO STAGGER! ${hero.name} chains off ally hit (+3 Combo DMG)!');
      }
      _lastComboActor = hero.id;

      final newEnemyHp = max(0, enemy.currentHp - dmg).toInt();
      enemy.currentHp = newEnemyHp;
      _enemyNpc = _enemyNpc.copyWith(currentHp: newEnemyHp);
      widget.onEnemyUpdated(_enemyNpc);

      setState(() {
        _floatingEnemyText = '-$dmg HP';
        _floatingEnemyColor = isCrit ? Colors.amberAccent : Colors.redAccent;
        _bannerText = isCrit
            ? '🔥 CRITICAL HIT! ${hero.name} dealt $dmg damage!'
            : '⚔️ HIT! ($d20+${hero.attackBonus}=$totalAtk vs AC ${enemy.armorClass}) for $dmg damage!';
        _bannerColor = isCrit ? Colors.amberAccent : Colors.greenAccent;
        _battleLog.insert(0, '${hero.name} strikes ${enemy.name} with ${hero.attackName} for $dmg damage!');
      });

      if (newEnemyHp <= 0) {
        _handleVictory(hero.name);
        return;
      }
    } else {
      _lastComboActor = null;
      AudioService.instance.playError();
      setState(() {
        _floatingEnemyText = 'PARRIED!';
        _floatingEnemyColor = Colors.white70;
        _bannerText = '🛡️ MISS! ($d20+${hero.attackBonus}=$totalAtk vs AC ${enemy.armorClass})';
        _bannerColor = Colors.white60;
        _battleLog.insert(0, '${hero.name}\'s attack was deflected by ${enemy.name}!');
      });
    }

    _broadcastCombatState();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _advanceTurn();
  }

  Future<void> _executeCastSpell(String spellName, int diceCount, int diceSides, int bonus, {bool isHeal = false, StatusType? inflictStatus}) async {
    final enemy = _enemyCombatant;
    if (_isActing || enemy == null || enemy.currentHp <= 0) return;
    final hero = _activeCombatant;

    setState(() {
      _isActing = true;
      _bannerText = null;
    });

    AudioService.instance.playSend();

    var amount = bonus;
    for (var i = 0; i < diceCount; i++) {
      amount += Random().nextInt(diceSides) + 1;
    }

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (isHeal) {
      // Heal lowest party member & cleanse negative statuses
      final wounded = _partyCombatants..sort((a, b) => (a.currentHp / a.maxHp).compareTo(b.currentHp / b.maxHp));
      final target = wounded.first;
      target.statuses.removeWhere((s) => s.type == StatusType.poisoned || s.type == StatusType.burning);
      final newHp = min(target.maxHp, target.currentHp + amount);
      target.currentHp = newHp;
      if (target.partyMember != null) {
        widget.onHeroDamaged(target.id, -amount);
      }

      setState(() {
        _floatingPartyTexts[target.id] = '+$amount HP (Purified)';
        _bannerText = '✨ $spellName restores +$amount HP to ${target.name} & purifies afflictions!';
        _bannerColor = Colors.cyanAccent;
        _battleLog.insert(0, '${hero.name} casts $spellName restoring $amount HP to ${target.name}!');
      });
    } else {
      // Offensive spell
      if (inflictStatus != null) {
        enemy.addStatus(inflictStatus, rounds: 2);
      }
      final newEnemyHp = max(0, enemy.currentHp - amount).toInt();
      enemy.currentHp = newEnemyHp;
      _enemyNpc = _enemyNpc.copyWith(currentHp: newEnemyHp);
      widget.onEnemyUpdated(_enemyNpc);

      final statusText = inflictStatus != null ? ' [${inflictStatus.name.toUpperCase()}!]' : '';
      setState(() {
        _floatingEnemyText = '-$amount HP$statusText';
        _floatingEnemyColor = Colors.purpleAccent;
        _bannerText = '⚡ $spellName blasts ${enemy.name} for $amount damage$statusText!';
        _bannerColor = Colors.purpleAccent;
        _battleLog.insert(0, '${hero.name} unleashes $spellName for $amount damage$statusText!');
      });

      if (newEnemyHp <= 0) {
        _handleVictory(hero.name);
        return;
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _advanceTurn();
  }

  void _executeDefensiveGuard() {
    final hero = _activeCombatant;
    setState(() {
      hero.isDefending = true;
      _bannerText = '🛡️ ${hero.name} assumes Defensive Stance (+3 AC until next turn)!';
      _bannerColor = Colors.blueAccent;
      _battleLog.insert(0, '${hero.name} raises guard and braces for incoming strikes.');
    });
    AudioService.instance.playTap();
    _advanceTurn();
  }

  void _executeUsePotion() {
    final hero = _activeCombatant;
    final heal = 12;
    hero.statuses.removeWhere((s) => s.type == StatusType.poisoned || s.type == StatusType.burning);
    final newHp = min(hero.maxHp, hero.currentHp + heal);
    hero.currentHp = newHp;
    if (hero.partyMember != null) {
      widget.onHeroDamaged(hero.id, -heal);
    }

    AudioService.instance.playSuccess();
    setState(() {
      _floatingPartyTexts[hero.id] = '+$heal HP (Cleanse)';
      _bannerText = '🧪 Quaffed Potion of Healing! (+12 HP & Cleansed)';
      _bannerColor = Colors.greenAccent;
      _battleLog.insert(0, '${hero.name} drinks an elixir, mending $heal HP and cleansing afflictions.');
    });
    _advanceTurn();
  }

  // --- AUTONOMOUS AI COMPANION TURN ---

  Future<void> _executeCompanionTurn(Combatant companion) async {
    final enemy = _enemyCombatant;
    if (enemy == null || enemy.currentHp <= 0) return;

    setState(() {
      _isActing = true;
      _bannerText = '🤖 ${companion.name} is executing tactics...';
      _bannerColor = ArcaneTheme.secondary;
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final role = companion.role.toLowerCase();
    final woundedAlly = _partyCombatants.where((c) => c.currentHp < c.maxHp * 0.45).firstOrNull;

    // 1. Cleric / Healer AI: Heal wounded ally if below 45% HP
    if ((role.contains('cleric') || role.contains('paladin')) && woundedAlly != null) {
      final heal = Random().nextInt(8) + 1 + 3;
      woundedAlly.currentHp = min(woundedAlly.maxHp, woundedAlly.currentHp + heal);
      if (woundedAlly.partyMember != null) {
        widget.onHeroDamaged(woundedAlly.id, -heal);
      }
      AudioService.instance.playSend();
      setState(() {
        _floatingPartyTexts[woundedAlly.id] = '+$heal HP';
        _bannerText = '✨ ${companion.name} casts Healing Word on ${woundedAlly.name} (+$heal HP)!';
        _bannerColor = Colors.cyanAccent;
        _battleLog.insert(0, '${companion.name} shouts: "Stay on your feet!" and heals ${woundedAlly.name} for $heal HP.');
      });
    }
    // 2. Wizard / Mage AI: Cast spell
    else if (role.contains('wizard') || role.contains('mage') || role.contains('sorcerer')) {
      final isHighAc = enemy.armorClass >= 14;
      if (isHighAc) {
        // Magic Missile: auto-hit
        final dmg = Random().nextInt(4) + 1 + Random().nextInt(4) + 1 + 3;
        final newHp = max(0, enemy.currentHp - dmg);
        enemy.currentHp = newHp;
        _enemyNpc = _enemyNpc.copyWith(currentHp: newHp);
        widget.onEnemyUpdated(_enemyNpc);
        AudioService.instance.playSend();

        setState(() {
          _floatingEnemyText = '-$dmg HP';
          _floatingEnemyColor = Colors.purpleAccent;
          _bannerText = '🔮 ${companion.name} fires Magic Missile for $dmg force damage!';
          _bannerColor = Colors.purpleAccent;
          _battleLog.insert(0, '${companion.name} intones an incantation: Magic Missile strikes ${enemy.name} for $dmg damage!');
        });

        if (newHp <= 0) {
          _handleVictory(companion.name);
          return;
        }
      } else {
        // Firebolt: roll to hit
        final d20 = Random().nextInt(20) + 1;
        final total = d20 + companion.attackBonus;
        if (d20 == 20 || total >= enemy.armorClass) {
          final dmg = Random().nextInt(10) + 1 + 2;
          final newHp = max(0, enemy.currentHp - dmg);
          enemy.currentHp = newHp;
          _enemyNpc = _enemyNpc.copyWith(currentHp: newHp);
          widget.onEnemyUpdated(_enemyNpc);
          AudioService.instance.playSend();

          setState(() {
            _floatingEnemyText = '-$dmg HP';
            _floatingEnemyColor = Colors.orangeAccent;
            _bannerText = '🔥 ${companion.name} hurls Firebolt for $dmg fire damage!';
            _bannerColor = Colors.orangeAccent;
            _battleLog.insert(0, '${companion.name} chants: Firebolt ignites ${enemy.name} for $dmg damage!');
          });

          if (newHp <= 0) {
            _handleVictory(companion.name);
            return;
          }
        } else {
          AudioService.instance.playError();
          setState(() {
            _bannerText = '💨 ${companion.name}\'s Firebolt missed!';
            _bannerColor = Colors.white60;
            _battleLog.insert(0, '${companion.name}\'s spell narrowly whistled past ${enemy.name}.');
          });
        }
      }
    }
    // 3. Rogue AI: Flank sneak attack
    else if (role.contains('rogue')) {
      final d20 = Random().nextInt(20) + 1;
      final total = d20 + companion.attackBonus;
      if (d20 == 20 || total >= enemy.armorClass) {
        final dmg = Random().nextInt(6) + 1 + Random().nextInt(6) + 1 + 2;
        final newHp = max(0, enemy.currentHp - dmg);
        enemy.currentHp = newHp;
        _enemyNpc = _enemyNpc.copyWith(currentHp: newHp);
        widget.onEnemyUpdated(_enemyNpc);
        AudioService.instance.playSend();

        setState(() {
          _floatingEnemyText = '-$dmg HP';
          _floatingEnemyColor = Colors.amberAccent;
          _bannerText = '🗡️ ${companion.name} performs Sneak Attack for $dmg damage!';
          _bannerColor = Colors.amberAccent;
          _battleLog.insert(0, '${companion.name} slips behind ${enemy.name} with a lethal flank for $dmg damage!');
        });

        if (newHp <= 0) {
          _handleVictory(companion.name);
          return;
        }
      } else {
        AudioService.instance.playError();
        setState(() {
          _bannerText = '🛡️ ${companion.name}\'s dagger was parried!';
          _bannerColor = Colors.white60;
          _battleLog.insert(0, '${companion.name}\'s strike glanced off ${enemy.name}.');
        });
      }
    }
    // 4. Paladin AI: Radiant Smite
    else if (role.contains('paladin')) {
      final d20 = Random().nextInt(20) + 1;
      final total = d20 + companion.attackBonus;
      if (d20 == 20 || total >= enemy.armorClass) {
        final smite = Random().nextInt(8) + 1 + Random().nextInt(8) + 1;
        final dmg = Random().nextInt(10) + 1 + 3 + smite;
        final newHp = max(0, enemy.currentHp - dmg);
        enemy.currentHp = newHp;
        _enemyNpc = _enemyNpc.copyWith(currentHp: newHp);
        widget.onEnemyUpdated(_enemyNpc);
        AudioService.instance.playSend();

        setState(() {
          _floatingEnemyText = '-$dmg HP';
          _floatingEnemyColor = Colors.amber;
          _bannerText = '✨ ${companion.name} strikes with Radiant Smite for $dmg holy damage!';
          _bannerColor = Colors.amber;
          _battleLog.insert(0, '${companion.name} invokes a sacred oath: "By righteous light!" smiting ${enemy.name} for $dmg damage.');
        });

        if (newHp <= 0) {
          _handleVictory(companion.name);
          return;
        }
      } else {
        AudioService.instance.playError();
        setState(() {
          _bannerText = '🛡️ ${companion.name}\'s smite was parried!';
          _bannerColor = Colors.white60;
          _battleLog.insert(0, '${companion.name}\'s radiant hammer struck wide of ${enemy.name}.');
        });
      }
    }
    // 5. Ranger AI: Hunter's Mark & Pinpoint Volley
    else if (role.contains('ranger')) {
      final d20 = Random().nextInt(20) + 1;
      final total = d20 + companion.attackBonus + 1;
      if (d20 == 20 || total >= enemy.armorClass) {
        final markDmg = Random().nextInt(6) + 1;
        final dmg = Random().nextInt(8) + 1 + 3 + markDmg;
        final newHp = max(0, enemy.currentHp - dmg);
        enemy.currentHp = newHp;
        _enemyNpc = _enemyNpc.copyWith(currentHp: newHp);
        widget.onEnemyUpdated(_enemyNpc);
        AudioService.instance.playSend();

        setState(() {
          _floatingEnemyText = '-$dmg HP';
          _floatingEnemyColor = Colors.greenAccent;
          _bannerText = '🏹 ${companion.name} looses Hunter\'s Volley for $dmg damage!';
          _bannerColor = Colors.greenAccent;
          _battleLog.insert(0, '${companion.name} marks the target and drives an arrow straight through ${enemy.name}\'s armor for $dmg damage!');
        });

        if (newHp <= 0) {
          _handleVictory(companion.name);
          return;
        }
      } else {
        AudioService.instance.playError();
        setState(() {
          _bannerText = '💨 ${companion.name}\'s arrow embedded in stone!';
          _bannerColor = Colors.white60;
          _battleLog.insert(0, '${companion.name}\'s bowshot whistled past ${enemy.name}.');
        });
      }
    }
    // 6. Barbarian AI: Reckless Frenzy
    else if (role.contains('barbarian')) {
      final d20_1 = Random().nextInt(20) + 1;
      final d20_2 = Random().nextInt(20) + 1;
      final d20 = max(d20_1, d20_2);
      final total = d20 + companion.attackBonus;
      if (d20 == 20 || total >= enemy.armorClass) {
        final dmg = Random().nextInt(12) + 1 + 5;
        final newHp = max(0, enemy.currentHp - dmg);
        enemy.currentHp = newHp;
        _enemyNpc = _enemyNpc.copyWith(currentHp: newHp);
        widget.onEnemyUpdated(_enemyNpc);
        AudioService.instance.playSend();

        setState(() {
          _floatingEnemyText = '-$dmg HP';
          _floatingEnemyColor = Colors.redAccent;
          _bannerText = '🪓 ${companion.name} enters Reckless Rage for $dmg damage!';
          _bannerColor = Colors.redAccent;
          _battleLog.insert(0, '${companion.name} roars in bloodthirsty fury, hacking into ${enemy.name} for $dmg damage!');
        });

        if (newHp <= 0) {
          _handleVictory(companion.name);
          return;
        }
      } else {
        AudioService.instance.playError();
        setState(() {
          _bannerText = '🛡️ ${companion.name}\'s wild axe glanced off!';
          _bannerColor = Colors.white60;
          _battleLog.insert(0, '${companion.name}\'s reckless swing crashed into the floor near ${enemy.name}.');
        });
      }
    }
    // 7. Bard AI: Vicious Mockery
    else if (role.contains('bard')) {
      final dmg = Random().nextInt(4) + 1 + Random().nextInt(4) + 1 + 2;
      final newHp = max(0, enemy.currentHp - dmg);
      enemy.currentHp = newHp;
      _enemyNpc = _enemyNpc.copyWith(currentHp: newHp);
      widget.onEnemyUpdated(_enemyNpc);
      AudioService.instance.playSend();

      setState(() {
        _floatingEnemyText = '-$dmg HP';
        _floatingEnemyColor = Colors.pinkAccent;
        _bannerText = '🎭 ${companion.name} casts Vicious Mockery for $dmg psychic damage!';
        _bannerColor = Colors.pinkAccent;
        _battleLog.insert(0, '${companion.name} mocks ${enemy.name} with biting verse, dealing $dmg psychic damage!');
      });

      if (newHp <= 0) {
        _handleVictory(companion.name);
        return;
      }
    }
    // 8. Fighter / Default Martial AI: Heavy Cleave
    else {
      final d20 = Random().nextInt(20) + 1;
      final total = d20 + companion.attackBonus;
      if (d20 == 20 || total >= enemy.armorClass) {
        var dmg = Random().nextInt(companion.damageDice) + 1 + 3;
        if (_lastComboActor != null && _lastComboActor != companion.id) {
          dmg += 3;
          _battleLog.insert(0, '⚡ COMBO STAGGER! ${companion.name} chains off previous hit (+3 Combo DMG)!');
        }
        _lastComboActor = companion.id;
        final newHp = max(0, enemy.currentHp - dmg);
        enemy.currentHp = newHp;
        _enemyNpc = _enemyNpc.copyWith(currentHp: newHp);
        widget.onEnemyUpdated(_enemyNpc);
        AudioService.instance.playSend();

        setState(() {
          _floatingEnemyText = '-$dmg HP';
          _floatingEnemyColor = Colors.redAccent;
          _bannerText = '⚔️ ${companion.name} lands Power Strike for $dmg damage!';
          _bannerColor = Colors.redAccent;
          _battleLog.insert(0, '${companion.name} roars and cleaves into ${enemy.name} for $dmg damage!');
        });

        if (newHp <= 0) {
          _handleVictory(companion.name);
          return;
        }
      } else {
        _lastComboActor = null;
        AudioService.instance.playError();
        setState(() {
          _bannerText = '🛡️ ${companion.name}\'s swing was blocked!';
          _bannerColor = Colors.white60;
          _battleLog.insert(0, '${companion.name}\'s cleave was turned aside by ${enemy.name}.');
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _advanceTurn();
  }

  // --- AUTONOMOUS ENEMY AI TURN ---

  Future<void> _executeEnemyTurn() async {
    _lastComboActor = null;
    final enemy = _enemyCombatant;
    if (enemy == null || enemy.currentHp <= 0) return;

    setState(() {
      _isActing = true;
      _bannerText = '⚠️ ${enemy.name} executes tactical intent...';
      _bannerColor = Colors.redAccent;
    });

    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    final livingParty = _partyCombatants.where((c) => c.currentHp > 0).toList();
    if (livingParty.isEmpty) return;

    final role = enemy.role.toLowerCase();
    final name = enemy.name.toLowerCase();

    // 1. Shadow Caster / Wraith AI: Dark Siphon or Shadow Curse
    if (role.contains('caster') || role.contains('shadow') || name.contains('cultist') || name.contains('wraith')) {
      if (enemy.currentHp < enemy.maxHp * 0.65) {
        // Dark Siphon (Leech Life)
        livingParty.sort((a, b) => a.currentHp.compareTo(b.currentHp));
        final target = livingParty.first;
        final d20 = Random().nextInt(20) + 1;
        final effectiveAc = target.armorClass + (target.isDefending ? 3 : 0);

        if (d20 == 20 || d20 + enemy.attackBonus >= effectiveAc) {
          final dmg = Random().nextInt(6) + 3;
          final targetHp = max(0, target.currentHp - dmg);
          target.currentHp = targetHp;
          if (target.partyMember != null) widget.onHeroDamaged(target.id, dmg);

          // Leech HP back
          final healedHp = min(enemy.maxHp, enemy.currentHp + dmg);
          enemy.currentHp = healedHp;
          _enemyNpc = _enemyNpc.copyWith(currentHp: healedHp);
          widget.onEnemyUpdated(_enemyNpc);

          AudioService.instance.playSend();
          setState(() {
            _floatingPartyTexts[target.id] = '-$dmg HP';
            _floatingEnemyText = '+$dmg HP';
            _floatingEnemyColor = Colors.purpleAccent;
            _bannerText = '🔮 Dark Siphon! ${enemy.name} drains $dmg HP from ${target.name} and heals!';
            _bannerColor = Colors.purpleAccent;
            _battleLog.insert(0, '${enemy.name} channels Dark Siphon, draining $dmg HP from ${target.name}!');
          });
        } else {
          AudioService.instance.playTap();
          setState(() {
            _bannerText = '🛡️ ${target.name} resisted Dark Siphon!';
            _bannerColor = Colors.white60;
            _battleLog.insert(0, '${target.name} resisted ${enemy.name}\'s dark siphon.');
          });
        }
      } else {
        // Shadow Curse: Inflicts Poison
        livingParty.sort((a, b) => a.armorClass.compareTo(b.armorClass));
        final target = livingParty.first;
        target.addStatus(StatusType.poisoned, rounds: 2);
        AudioService.instance.playSend();
        setState(() {
          _floatingPartyTexts[target.id] = 'POISONED!';
          _bannerText = '💀 Shadow Curse! ${target.name} is afflicted with Poison!';
          _bannerColor = Colors.greenAccent;
          _battleLog.insert(0, '${enemy.name} blights ${target.name} with dark poison!');
        });
      }
    }
    // 2. Armored Sentry / Skeleton AI: Phalanx Bulwark or Shield Bash (Stun)
    else if (role.contains('sentry') || role.contains('guardian') || name.contains('skeleton') || name.contains('golem')) {
      if (!enemy.isShielded && enemy.currentHp < enemy.maxHp * 0.7 && Random().nextDouble() < 0.5) {
        enemy.addStatus(StatusType.shielded, rounds: 2);
        AudioService.instance.playSend();
        setState(() {
          _floatingEnemyText = '+4 AC (GUARD)';
          _floatingEnemyColor = Colors.blueAccent;
          _bannerText = '🛡️ ${enemy.name} fortifies Phalanx Bulwark (+4 AC)!';
          _bannerColor = Colors.blueAccent;
          _battleLog.insert(0, '${enemy.name} braces behind its shield, bolstering defenses (+4 AC)!');
        });
      } else {
        // Shield Bash with Stun chance
        livingParty.sort((a, b) => a.armorClass.compareTo(b.armorClass));
        final target = livingParty.first;

        // Tank Intercept Check
        final tank = _partyCombatants.where((c) => c.isCompanion && c.currentHp > 0 && (c.role.toLowerCase().contains('paladin') || c.role.toLowerCase().contains('fighter') || c.role.toLowerCase().contains('barbarian'))).firstOrNull;
        if (tank != null && target.isPlayer && Random().nextDouble() < 0.35) {
          final dmg = Random().nextInt(enemy.damageDice) + 1;
          tank.currentHp = max(0, tank.currentHp - dmg);
          AudioService.instance.playTap();
          setState(() {
            _floatingPartyTexts[tank.id] = '-$dmg HP (INTERCEPT!)';
            _bannerText = '🛡️ ${tank.name} leaps forward and INTERCEPTS the blow meant for ${target.name}!';
            _bannerColor = Colors.cyanAccent;
            _battleLog.insert(0, '🛡️ ${tank.name} heroically blocks ${enemy.name}\'s bash for ${target.name}!');
          });
        } else {
          final d20 = Random().nextInt(20) + 1;
          final effectiveAc = target.armorClass + (target.isDefending ? 3 : 0);
          if (d20 == 20 || d20 + enemy.attackBonus >= effectiveAc) {
            final dmg = Random().nextInt(enemy.damageDice) + 2;
            final newHp = max(0, target.currentHp - dmg);
            target.currentHp = newHp;
            if (target.partyMember != null) widget.onHeroDamaged(target.id, dmg);

            final didStun = Random().nextDouble() < 0.45;
            if (didStun) target.addStatus(StatusType.stunned, rounds: 1);

            AudioService.instance.playError();
            setState(() {
              _floatingPartyTexts[target.id] = didStun ? '-$dmg HP (STUN!)' : '-$dmg HP';
              _bannerText = didStun
                  ? '⚡ SHIELD SLAM! ${target.name} takes $dmg dmg and is STUNNED!'
                  : '🛡️ ${enemy.name} bashes ${target.name} for $dmg damage!';
              _bannerColor = didStun ? Colors.amberAccent : Colors.redAccent;
              _battleLog.insert(0, '${enemy.name} slams ${target.name} with its shield for $dmg damage${didStun ? " (STUNNED!)" : ""}!');
            });
          } else {
            AudioService.instance.playTap();
            setState(() {
              _floatingPartyTexts[target.id] = 'DEFLECTED!';
              _bannerText = '🛡️ ${target.name} deflected the shield bash!';
              _bannerColor = Colors.white60;
              _battleLog.insert(0, '${target.name} deflected ${enemy.name}\'s shield slam.');
            });
          }
        }
      }
    }
    // 3. Brute / Berserker / Orc AI: Blood Frenzy Enrage
    else if (role.contains('brute') || role.contains('berserker') || name.contains('orc')) {
      if (enemy.currentHp < enemy.maxHp * 0.5 && !enemy.isEnraged) {
        enemy.addStatus(StatusType.enraged, rounds: 3);
        AudioService.instance.playError();
        setState(() {
          _floatingEnemyText = 'ENRAGED! (+3 DMG)';
          _floatingEnemyColor = Colors.redAccent;
          _bannerText = '💢 BLOOD FRENZY! ${enemy.name} enters Enrage (+3 Damage)!';
          _bannerColor = Colors.redAccent;
          _battleLog.insert(0, '${enemy.name} howls in bloodthirsty rage! Eyes blazing with frenzy (+3 DMG)!');
        });
      } else {
        livingParty.shuffle();
        final target = livingParty.first;
        final d20 = Random().nextInt(20) + 1;
        final effectiveAc = target.armorClass + (target.isDefending ? 3 : 0);
        if (d20 == 20 || d20 + enemy.attackBonus >= effectiveAc) {
          final frenzyBonus = enemy.isEnraged ? 3 : 0;
          final dmg = Random().nextInt(enemy.damageDice) + 2 + frenzyBonus;
          final newHp = max(0, target.currentHp - dmg);
          target.currentHp = newHp;
          if (target.partyMember != null) widget.onHeroDamaged(target.id, dmg);

          AudioService.instance.playError();
          setState(() {
            _floatingPartyTexts[target.id] = '-$dmg HP';
            _bannerText = '🪓 ${enemy.name} cleaves ${target.name} for $dmg damage!';
            _bannerColor = Colors.redAccent;
            _battleLog.insert(0, '${enemy.name} drives a brutal cleaver into ${target.name} for $dmg damage!');
          });
        } else {
          AudioService.instance.playTap();
          setState(() {
            _floatingPartyTexts[target.id] = 'DODGED!';
            _bannerText = '💨 ${target.name} dodged ${enemy.name}\'s wild cleave!';
            _bannerColor = Colors.white60;
            _battleLog.insert(0, '${target.name} dodged ${enemy.name}\'s wild cleave.');
          });
        }
      }
    }
    // 4. Skulker / Raider / Goblin AI: Poison Ambush on lowest HP hero
    else if (role.contains('raider') || role.contains('skulker') || name.contains('goblin')) {
      livingParty.sort((a, b) => a.currentHp.compareTo(b.currentHp));
      final target = livingParty.first;
      final d20 = Random().nextInt(20) + 1;
      final effectiveAc = target.armorClass + (target.isDefending ? 3 : 0);
      if (d20 == 20 || d20 + enemy.attackBonus >= effectiveAc) {
        final dmg = Random().nextInt(enemy.damageDice) + 1;
        final newHp = max(0, target.currentHp - dmg);
        target.currentHp = newHp;
        if (target.partyMember != null) widget.onHeroDamaged(target.id, dmg);

        target.addStatus(StatusType.poisoned, rounds: 2);

        AudioService.instance.playError();
        setState(() {
          _floatingPartyTexts[target.id] = '-$dmg HP (POISON)';
          _bannerText = '🧪 ${enemy.name} stabs ${target.name} for $dmg dmg and inflicts Poison!';
          _bannerColor = Colors.greenAccent;
          _battleLog.insert(0, '${enemy.name} ambushes ${target.name} with a poisoned stiletto!');
        });
      } else {
        AudioService.instance.playTap();
        setState(() {
          _floatingPartyTexts[target.id] = 'PARRIED!';
          _bannerText = '🛡️ ${target.name} parried ${enemy.name}\'s dagger!';
          _bannerColor = Colors.white60;
          _battleLog.insert(0, '${target.name} parried ${enemy.name}\'s dagger strike.');
        });
      }
    }
    // Default melee attack
    else {
      livingParty.sort((a, b) => a.armorClass.compareTo(b.armorClass));
      final target = livingParty.first;
      final d20 = Random().nextInt(20) + 1;
      final effectiveAc = target.armorClass + (target.isDefending ? 3 : 0);
      if (d20 == 20 || d20 + enemy.attackBonus >= effectiveAc) {
        final dmg = Random().nextInt(enemy.damageDice) + 2;
        final newHp = max(0, target.currentHp - dmg);
        target.currentHp = newHp;
        if (target.partyMember != null) widget.onHeroDamaged(target.id, dmg);

        AudioService.instance.playError();
        setState(() {
          _floatingPartyTexts[target.id] = '-$dmg HP';
          _bannerText = '⚔️ ${enemy.name} strikes ${target.name} for $dmg damage!';
          _bannerColor = Colors.redAccent;
          _battleLog.insert(0, '${enemy.name} strikes ${target.name} with ${enemy.attackName} dealing $dmg damage!');
        });
      } else {
        AudioService.instance.playTap();
        setState(() {
          _floatingPartyTexts[target.id] = 'DEFLECTED!';
          _bannerText = '🛡️ ${target.name} deflected ${enemy.name}\'s attack!';
          _bannerColor = Colors.blueAccent;
          _battleLog.insert(0, '${enemy.name}\'s attack was deflected by ${target.name}.');
        });
      }
    }

    _prepareNextEnemyIntent();

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _advanceTurn();
  }

  void _handleVictory(String vanquisher) async {
    final enemy = _enemyCombatant;
    AudioService.instance.playSuccess();
    setState(() {
      _battleLog.insert(0, '🏆 VICTORY! ${enemy?.name ?? "The enemy"} has fallen!');
      _bannerText = 'VICTORY! The chamber is cleared!';
      _bannerColor = Colors.amberAccent;
    });
    _broadcastCombatState(active: false);

    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      widget.onEnemyDefeated(_enemyNpc);
      widget.onCombatNarration('$vanquisher and the party vanquished the ${_enemyNpc.name} after a tactical turn-based battle!');
      Navigator.pop(context);
    }
  }

  void _showSpellPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161A26),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('CHOOSE SPELL', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.flash_on_rounded, color: Colors.purpleAccent),
              title: const Text('Magic Missile (Force Damage)'),
              subtitle: const Text('3d4 + 3 guaranteed force damage (Never misses)'),
              onTap: () {
                Navigator.pop(ctx);
                _executeCastSpell('Magic Missile', 3, 4, 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent),
              title: const Text('Firebolt (Incendiary Ray)'),
              subtitle: const Text('1d10 + 2 fire damage • Inflicts Burning 🔥'),
              onTap: () {
                Navigator.pop(ctx);
                _executeCastSpell('Firebolt', 1, 10, 2, inflictStatus: StatusType.burning);
              },
            ),
            ListTile(
              leading: const Icon(Icons.waves_rounded, color: Colors.amberAccent),
              title: const Text('Thunderwave (Concussive Blast)'),
              subtitle: const Text('2d6 + 2 thunder damage • Inflicts Stun ⚡'),
              onTap: () {
                Navigator.pop(ctx);
                _executeCastSpell('Thunderwave', 2, 6, 2, inflictStatus: StatusType.stunned);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_rounded, color: Colors.greenAccent),
              title: const Text('Healing Touch (Divine Restoration)'),
              subtitle: const Text('2d8 + 2 healing to lowest HP ally • Cleanses afflictions'),
              onTap: () {
                Navigator.pop(ctx);
                _executeCastSpell('Healing Touch', 2, 8, 2, isHeal: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enemy = _enemyCombatant;
    final active = _activeCombatant;
    final isPlayerTurn = active.isPlayer && !_autoBattle && !_isActing;
    final enemyHpRatio = enemy != null ? (enemy.currentHp / max(1, enemy.maxHp)).clamp(0.0, 1.0) : 0.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF10121A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.red.withValues(alpha: 0.2), blurRadius: 28, spreadRadius: 3),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 10),

          // Header with Round & Auto-Battle toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 18, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(
                    'TACTICAL BATTLE • ROUND $_roundNumber',
                    style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _autoBattle = !_autoBattle;
                      });
                      if (_autoBattle && active.isPlayer) {
                        _checkTriggerAiTurn();
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _autoBattle ? ArcaneTheme.secondary.withValues(alpha: 0.3) : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _autoBattle ? ArcaneTheme.secondary : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.smart_toy_rounded,
                            size: 14,
                            color: _autoBattle ? ArcaneTheme.secondary : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _autoBattle ? 'AI AUTO: ON' : 'AI AUTO: OFF',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _autoBattle ? ArcaneTheme.secondary : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white54),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),

          if (widget.activePet != null && widget.activePet!.id != 'none') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.activePet!.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.activePet!.color.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Text(widget.activePet!.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.activePet!.name.toUpperCase()} • ${widget.activePet!.perkTitle.toUpperCase()}',
                          style: GoogleFonts.cinzel(fontSize: 10.5, fontWeight: FontWeight.w700, color: widget.activePet!.color),
                        ),
                        Text(
                          widget.activePet!.perkDescription,
                          style: GoogleFonts.ibmPlexSans(fontSize: 10, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // INITIATIVE TURN RIBBON
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _combatants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final c = _combatants[i];
                final isActive = i == _currentTurnIndex;
                final isDead = c.currentHp <= 0;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? (c.isEnemy ? Colors.red.shade900.withValues(alpha: 0.5) : ArcaneTheme.primary.withValues(alpha: 0.5))
                        : Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive
                          ? (c.isEnemy ? Colors.redAccent : ArcaneTheme.secondary)
                          : Colors.white12,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.isEnemy ? Colors.redAccent : ArcaneTheme.secondary, width: 1.5),
                          image: DecorationImage(image: AssetImage(c.portraitAsset), fit: BoxFit.cover),
                        ),
                        child: isDead
                            ? Container(
                                color: Colors.black54,
                                child: const Icon(Icons.close, color: Colors.red, size: 20),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            c.name,
                            style: GoogleFonts.cinzel(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDead ? Colors.white38 : Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${c.currentHp}/${c.maxHp} HP',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 10,
                                  color: c.currentHp < c.maxHp * 0.4 ? Colors.redAccent : Colors.white60,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(3)),
                                  child: Text('TURN', style: GoogleFonts.ibmPlexSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // ENEMY INTENT RADAR BANNER
          if (enemy != null && _telegraphedEnemyIntent != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.7), width: 1),
              ),
              child: Row(
                children: [
                  Pulse(
                    duration: const Duration(milliseconds: 1100),
                    child: const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amberAccent),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ENEMY INTENT: ',
                    style: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.amberAccent),
                  ),
                  Expanded(
                    child: Text(
                      _telegraphedEnemyIntent!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // ENEMY ARENA CARD
          if (enemy != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade900.withValues(alpha: 0.35), const Color(0xFF1C1420)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.2),
              ),
              child: Row(
                children: [
                  Pulse(
                    duration: const Duration(milliseconds: 1400),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent, width: 2),
                        image: DecorationImage(image: AssetImage(enemy.portraitAsset), fit: BoxFit.cover),
                        boxShadow: [
                          BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              enemy.name.toUpperCase(),
                              style: GoogleFonts.cinzel(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.redAccent, width: 0.8),
                              ),
                              child: Text('🛡️ AC ${enemy.armorClass + (enemy.isShielded ? 4 : 0)}', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.redAccent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(enemy.role, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: enemyHpRatio,
                                  backgroundColor: Colors.black54,
                                  valueColor: AlwaysStoppedAnimation(
                                    enemyHpRatio > 0.45 ? Colors.redAccent : Colors.orangeAccent,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${enemy.currentHp}/${enemy.maxHp} HP', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                        if (enemy.statuses.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: enemy.statuses.map((st) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: st.color.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: st.color, width: 0.8),
                              ),
                              child: Text(
                                '${st.icon} ${st.label} (${st.remainingRounds})',
                                style: GoogleFonts.ibmPlexSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: st.color),
                              ),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_floatingEnemyText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _floatingEnemyColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _floatingEnemyColor, width: 1),
                      ),
                      child: Text(
                        _floatingEnemyText!,
                        style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w800, color: _floatingEnemyColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 10),

          // PARTY COMBATANTS CARDS
          Text('PARTY FORMATION', style: GoogleFonts.cinzel(fontSize: 11, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary)),
          const SizedBox(height: 6),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _partyCombatants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final hero = _partyCombatants[i];
                final isCurrent = hero.id == active.id;
                final hpRatio = (hero.currentHp / max(1, hero.maxHp)).clamp(0.0, 1.0);

                return Container(
                  width: 148,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCurrent ? ArcaneTheme.primary.withValues(alpha: 0.3) : const Color(0xFF141824),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurrent ? ArcaneTheme.secondary : (hero.isDefending ? Colors.blueAccent : Colors.white12),
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isCurrent ? ArcaneTheme.secondary : Colors.white30, width: 1.5),
                          image: DecorationImage(image: AssetImage(hero.portraitAsset), fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              hero.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cinzel(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            Text(
                              '${hero.role}${hero.isDefending ? " (Guard)" : ""}',
                              maxLines: 1,
                              style: GoogleFonts.ibmPlexSans(fontSize: 10, color: hero.isDefending ? Colors.blueAccent : Colors.white54),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: hpRatio,
                                backgroundColor: Colors.black45,
                                valueColor: AlwaysStoppedAnimation(
                                  hpRatio > 0.4 ? Colors.greenAccent : Colors.redAccent,
                                ),
                                minHeight: 5,
                              ),
                            ),
                            if (hero.statuses.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: hero.statuses.map((s) => Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: Text(s.icon, style: const TextStyle(fontSize: 9)),
                                  )).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // TURN & ACTION BANNER
          if (_bannerText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _bannerColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _bannerColor.withValues(alpha: 0.8), width: 1),
              ),
              child: Text(
                _bannerText!,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),

          const SizedBox(height: 10),

          // ACTION BUTTONS (Visible on player's turn)
          if (isPlayerTurn)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: Text('Attack (d20+${active.attackBonus})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: _executeMeleeAttack,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: const Text('Spells'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ArcaneTheme.secondary,
                      side: const BorderSide(color: ArcaneTheme.secondary),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: _showSpellPicker,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.shield_rounded, color: Colors.blueAccent),
                  tooltip: 'Defensive Guard (+3 AC)',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.blueAccent)),
                  ),
                  onPressed: _executeDefensiveGuard,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.local_hospital_rounded, color: Colors.greenAccent),
                  tooltip: 'Potion (+10 HP)',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.greenAccent)),
                  ),
                  onPressed: _executeUsePotion,
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(ArcaneTheme.secondary)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    active.isEnemy
                        ? '${active.name} is attacking...'
                        : active.isCompanion
                            ? '${active.name} (AI) is deciding tactical actions...'
                            : 'Resolving tactical turn...',
                    style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // SCROLLING BATTLE LOG
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: ListView.builder(
                reverse: false,
                itemCount: _battleLog.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    _battleLog[i],
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: i == 0 ? Colors.white : Colors.white60,
                      fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}