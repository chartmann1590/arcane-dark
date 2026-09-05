import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../domain/campaign_state.dart';
import '../domain/ability_scores.dart';
import '../features/play/tavern_populator.dart';
import '../services/audio_service.dart';
import 'fx.dart';

class TacticalCombatSheet extends StatefulWidget {
  final MapNpc initialEnemy;
  final CampaignState campaign;
  final void Function(MapNpc updatedEnemy) onEnemyUpdated;
  final void Function(MapNpc defeatedEnemy) onEnemyDefeated;
  final void Function(String characterId, int damage) onHeroDamaged;
  final void Function(String combatNarration) onCombatNarration;

  const TacticalCombatSheet({
    super.key,
    required this.initialEnemy,
    required this.campaign,
    required this.onEnemyUpdated,
    required this.onEnemyDefeated,
    required this.onHeroDamaged,
    required this.onCombatNarration,
  });

  @override
  State<TacticalCombatSheet> createState() => _TacticalCombatSheetState();
}

class _TacticalCombatSheetState extends State<TacticalCombatSheet> {
  late MapNpc _enemy;
  late int _selectedHeroIndex;
  final List<String> _battleLog = [];
  bool _isActing = false;
  String? _lastRollBanner;

  @override
  void initState() {
    super.initState();
    _enemy = widget.initialEnemy;
    _selectedHeroIndex = 0;
    _battleLog.add('Engaged with ${_enemy.name} (${_enemy.role})! Choose your action.');
  }

  PartyMemberStatus get _activeHero {
    if (widget.campaign.party.isEmpty) {
      return PartyMemberStatus(
        characterId: 'hero',
        name: 'Adventurer',
        raceLabel: 'Human',
        classLabel: 'Fighter',
        persona: '',
        abilities: const AbilityScores(),
        hp: 20,
        maxHp: 20,
        armorClass: 14,
      );
    }
    final idx = _selectedHeroIndex.clamp(0, widget.campaign.party.length - 1);
    return widget.campaign.party[idx];
  }

  int _heroAttackBonus(PartyMemberStatus hero) {
    final strMod = hero.abilities.strMod;
    final dexMod = hero.abilities.dexMod;
    return max(strMod, dexMod) + 2; // +2 proficiency
  }

  Future<void> _executeMeleeAttack() async {
    if (_isActing || _enemy.currentHp <= 0) return;
    setState(() {
      _isActing = true;
      _lastRollBanner = null;
    });

    AudioService.instance.playDiceRoll();
    final d20 = Random().nextInt(20) + 1;
    final hero = _activeHero;
    final atkBonus = _heroAttackBonus(hero);
    final totalAtk = d20 + atkBonus;
    final isCrit = d20 == 20;
    final isHit = isCrit || (d20 > 1 && totalAtk >= _enemy.armorClass);

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (isHit) {
      AudioService.instance.playSend();
      final weaponDice = hero.classLabel.toLowerCase().contains('rogue') ? 6 : 8;
      var dmg = Random().nextInt(weaponDice) + 1 + max(1, atkBonus - 2);
      if (isCrit) dmg *= 2;

      final newEnemyHp = max(0, _enemy.currentHp - dmg).toInt();
      _enemy = _enemy.copyWith(currentHp: newEnemyHp);
      widget.onEnemyUpdated(_enemy);

      setState(() {
        _lastRollBanner = isCrit
            ? 'NATURAL 20! CRITICAL HIT for $dmg damage!'
            : 'Roll: $d20 + $atkBonus = $totalAtk vs AC ${_enemy.armorClass} -> HIT for $dmg damage!';
        _battleLog.insert(0, '${hero.name} strikes ${_enemy.name} for $dmg damage!');
      });

      if (newEnemyHp <= 0) {
        AudioService.instance.playSuccess();
        setState(() {
          _battleLog.insert(0, 'VICTORY! ${_enemy.name} collapses into dust!');
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          widget.onEnemyDefeated(_enemy);
          widget.onCombatNarration('${hero.name} strikes down the ${_enemy.name} with a decisive attack!');
          Navigator.pop(context);
        }
        return;
      }
    } else {
      AudioService.instance.playError();
      setState(() {
        _lastRollBanner = 'Roll: $d20 + $atkBonus = $totalAtk vs AC ${_enemy.armorClass} -> MISS!';
        _battleLog.insert(0, '${hero.name}\'s strike glanced off ${_enemy.name}\'s defenses!');
      });
    }

    // Enemy Retaliation
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final enemyD20 = Random().nextInt(20) + 1;
    final enemyTotal = enemyD20 + _enemy.attackBonus;
    final enemyHit = enemyD20 > 1 && enemyTotal >= hero.armorClass;

    if (enemyHit) {
      AudioService.instance.playError();
      final enemyDmg = Random().nextInt(_enemy.damageDice) + 1 + 1;
      widget.onHeroDamaged(hero.characterId, enemyDmg);
      setState(() {
        _battleLog.insert(0, '${_enemy.name} retaliates with ${_enemy.attackName}! Hits ${hero.name} for $enemyDmg damage!');
      });
    } else {
      setState(() {
        _battleLog.insert(0, '${_enemy.name} lashes out with ${_enemy.attackName}, but ${hero.name} parries!');
      });
    }

    setState(() => _isActing = false);
  }

  Future<void> _executeSpell(String spellName, int diceCount, int diceSides, int bonus) async {
    if (_isActing || _enemy.currentHp <= 0) return;
    setState(() {
      _isActing = true;
      _lastRollBanner = null;
    });

    AudioService.instance.playSend();
    final hero = _activeHero;

    var dmg = bonus;
    for (var i = 0; i < diceCount; i++) {
      dmg += Random().nextInt(diceSides) + 1;
    }

    final newEnemyHp = max(0, _enemy.currentHp - dmg).toInt();
    _enemy = _enemy.copyWith(currentHp: newEnemyHp);
    widget.onEnemyUpdated(_enemy);

    setState(() {
      _lastRollBanner = '$spellName blasts ${_enemy.name} for $dmg arcane damage!';
      _battleLog.insert(0, '${hero.name} casts $spellName dealing $dmg damage!');
    });

    if (newEnemyHp <= 0) {
      AudioService.instance.playSuccess();
      setState(() {
        _battleLog.insert(0, 'VICTORY! ${_enemy.name} disintegrated by spellfire!');
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        widget.onEnemyDefeated(_enemy);
        widget.onCombatNarration('${hero.name} vanquished the ${_enemy.name} with a luminous $spellName spell!');
        Navigator.pop(context);
      }
      return;
    }

    // Enemy Retaliation
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final enemyD20 = Random().nextInt(20) + 1;
    final enemyTotal = enemyD20 + _enemy.attackBonus;
    final enemyHit = enemyD20 > 1 && enemyTotal >= hero.armorClass;

    if (enemyHit) {
      AudioService.instance.playError();
      final enemyDmg = Random().nextInt(_enemy.damageDice) + 1 + 1;
      widget.onHeroDamaged(hero.characterId, enemyDmg);
      setState(() {
        _battleLog.insert(0, '${_enemy.name} closes distance! Strikes ${hero.name} for $enemyDmg damage!');
      });
    }

    setState(() => _isActing = false);
  }

  Future<void> _executeCompanionAssist() async {
    if (_isActing || _enemy.currentHp <= 0) return;
    final companions = widget.campaign.party.skip(1).toList();
    if (companions.isEmpty) return;
    setState(() {
      _isActing = true;
      _lastRollBanner = null;
    });

    AudioService.instance.playDiceRoll();
    final companion = companions[Random().nextInt(companions.length)];
    final d20 = Random().nextInt(20) + 1;
    final bonus = _heroAttackBonus(companion);
    final totalAtk = d20 + bonus;
    final isHit = d20 == 20 || (d20 > 1 && totalAtk >= _enemy.armorClass);

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (isHit) {
      AudioService.instance.playSend();
      final dmg = Random().nextInt(6) + 1 + 2;
      final newEnemyHp = max(0, _enemy.currentHp - dmg).toInt();
      _enemy = _enemy.copyWith(currentHp: newEnemyHp);
      widget.onEnemyUpdated(_enemy);

      setState(() {
        _lastRollBanner = '${companion.name} assists! Strikes ${_enemy.name} for $dmg damage!';
        _battleLog.insert(0, '${companion.name} steps in with an assist strike dealing $dmg damage!');
      });

      if (newEnemyHp <= 0) {
        AudioService.instance.playSuccess();
        setState(() {
          _battleLog.insert(0, 'VICTORY! ${_enemy.name} defeated by party teamwork!');
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          widget.onEnemyDefeated(_enemy);
          widget.onCombatNarration('${companion.name} and the party vanquished the ${_enemy.name} in coordinated combat!');
          Navigator.pop(context);
        }
        return;
      }
    } else {
      AudioService.instance.playError();
      setState(() {
        _lastRollBanner = '${companion.name}\'s flanking strike was parried!';
        _battleLog.insert(0, '${companion.name}\'s assist strike missed ${_enemy.name}.');
      });
    }

    // Enemy Retaliation
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final enemyD20 = Random().nextInt(20) + 1;
    final enemyTotal = enemyD20 + _enemy.attackBonus;
    final enemyHit = enemyD20 > 1 && enemyTotal >= _activeHero.armorClass;

    if (enemyHit) {
      AudioService.instance.playError();
      final enemyDmg = Random().nextInt(_enemy.damageDice) + 1 + 1;
      widget.onHeroDamaged(_activeHero.characterId, enemyDmg);
      setState(() {
        _battleLog.insert(0, '${_enemy.name} lashes back! Hits ${_activeHero.name} for $enemyDmg damage!');
      });
    } else {
      setState(() {
        _battleLog.insert(0, '${_enemy.name} strikes, but ${_activeHero.name} parries!');
      });
    }

    setState(() => _isActing = false);
  }

  @override
  Widget build(BuildContext context) {
    final hpRatio = (_enemy.currentHp / max(1, _enemy.maxHp)).clamp(0.0, 1.0);
    final party = widget.campaign.party;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: ArcaneTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Target Header
          Row(
            children: [
              Pulse(
                duration: const Duration(milliseconds: 1600),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2),
                    image: DecorationImage(image: AssetImage(_enemy.portraitAsset), fit: BoxFit.cover),
                    boxShadow: [
                      BoxShadow(color: Colors.redAccent.withValues(alpha: 0.5), blurRadius: 10),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _enemy.name.toUpperCase(),
                          style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.redAccent, width: 0.8),
                          ),
                          child: Text(
                            'AC ${_enemy.armorClass}',
                            style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_enemy.role, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
                    const SizedBox(height: 6),
                    // HP Bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: hpRatio,
                              backgroundColor: Colors.black45,
                              valueColor: AlwaysStoppedAnimation(
                                hpRatio > 0.4 ? Colors.redAccent : Colors.amberAccent,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_enemy.currentHp} / ${_enemy.maxHp} HP',
                          style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Party Member Selector Strip
          if (party.length > 1) ...[
            Text('ACTING COMBATANT', style: GoogleFonts.cinzel(fontSize: 11, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary)),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: party.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final hero = party[i];
                  final isSelected = _selectedHeroIndex == i;
                  return ChoiceChip(
                    label: Text('${hero.name} (${hero.classLabel}) - ${hero.hp} HP'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedHeroIndex = i);
                    },
                    selectedColor: ArcaneTheme.primary.withValues(alpha: 0.35),
                    backgroundColor: ArcaneTheme.surface,
                    labelStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white60,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Roll result banner
          if (_lastRollBanner != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _lastRollBanner!.contains('HIT')
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _lastRollBanner!.contains('HIT') ? Colors.greenAccent : Colors.redAccent,
                  width: 1,
                ),
              ),
              child: Text(
                _lastRollBanner!,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Combat Action Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: Text('Strike (d20+${_heroAttackBonus(_activeHero)})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isActing ? null : _executeMeleeAttack,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('Spell (Magic Missile)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ArcaneTheme.secondary,
                    side: const BorderSide(color: ArcaneTheme.secondary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isActing ? null : () => _executeSpell('Magic Missile', 3, 4, 3),
                ),
              ),
            ],
          ),
          if (party.length > 1) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.group_rounded, size: 16),
              label: const Text('Companion Coordinated Flank Strike'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ArcaneTheme.secondary.withValues(alpha: 0.25),
                foregroundColor: Colors.white,
                side: const BorderSide(color: ArcaneTheme.secondary),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: _isActing ? null : _executeCompanionAssist,
            ),
          ],

          const SizedBox(height: 10),

          // Battle Log Box
          Container(
            height: 80,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.builder(
              reverse: true,
              itemCount: _battleLog.length,
              itemBuilder: (ctx, i) => Text(
                '• ${_battleLog[i]}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  color: i == 0 ? Colors.white : Colors.white60,
                  fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Disengage Button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Disengage & Withdraw',
              style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}