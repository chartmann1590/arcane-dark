import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../domain/ability_scores.dart';
import '../../../domain/character.dart';
import '../../../providers/character_provider.dart';
import '../../../services/audio_service.dart';

class AbilitiesStep extends ConsumerWidget {
  const AbilitiesStep({super.key});

  int _rollSingleStat() {
    final rolls = List.generate(4, (_) => Random().nextInt(6) + 1)..sort();
    return rolls[1] + rolls[2] + rolls[3]; // drop lowest
  }

  void _rollAll(BuildContext context, WidgetRef ref) {
    AudioService.instance.playDiceRoll();
    final scores = AbilityScores(
      str: _rollSingleStat().clamp(8, 18),
      dex: _rollSingleStat().clamp(8, 18),
      con: _rollSingleStat().clamp(8, 18),
      int_: _rollSingleStat().clamp(8, 18),
      wis: _rollSingleStat().clamp(8, 18),
      cha: _rollSingleStat().clamp(8, 18),
    );
    ref.read(characterDraftProvider.notifier).setAbilities(scores);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎲 Rolled 4d6 (drop lowest) for all ability scores!', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600)),
        backgroundColor: ArcaneTheme.secondary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applyStandardArray(BuildContext context, WidgetRef ref, CharClass charClass) {
    AudioService.instance.playSuccess();
    final AbilityScores scores;
    switch (charClass) {
      case CharClass.fighter:
      case CharClass.barbarian:
        scores = const AbilityScores(str: 15, con: 14, dex: 13, wis: 12, cha: 10, int_: 8);
        break;
      case CharClass.wizard:
        scores = const AbilityScores(int_: 15, dex: 14, con: 13, wis: 12, cha: 10, str: 8);
        break;
      case CharClass.rogue:
        scores = const AbilityScores(dex: 15, cha: 14, con: 13, int_: 12, wis: 10, str: 8);
        break;
      case CharClass.cleric:
        scores = const AbilityScores(wis: 15, con: 14, str: 13, cha: 12, int_: 10, dex: 8);
        break;
      case CharClass.paladin:
        scores = const AbilityScores(str: 15, cha: 14, con: 13, wis: 12, dex: 10, int_: 8);
        break;
      case CharClass.ranger:
        scores = const AbilityScores(dex: 15, wis: 14, con: 13, str: 12, int_: 10, cha: 8);
        break;
      case CharClass.bard:
        scores = const AbilityScores(cha: 15, dex: 14, con: 13, int_: 12, wis: 10, str: 8);
        break;
    }
    ref.read(characterDraftProvider.notifier).setAbilities(scores);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚡ Standard Array allocated for ${charClass.label}!', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600)),
        backgroundColor: ArcaneTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    final abilities = draft.abilities;
    final cost = abilities.totalCost();
    final remaining = 27 - cost;
    final over = remaining < 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(children: [
          Expanded(child: Text('27-point buy — raise scores before racial bonuses. Scores 8–15.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary))),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: over ? ArcaneTheme.tertiary.withOpacity(0.15) : ArcaneTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: over ? ArcaneTheme.tertiary.withOpacity(0.4) : ArcaneTheme.primary.withOpacity(0.3))),
            child: Row(children: [
              Icon(over ? Icons.error_rounded : Icons.stars_rounded, size: 14, color: over ? ArcaneTheme.tertiary : ArcaneTheme.primary),
              const SizedBox(width: 6),
              Text('$remaining pts', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800, fontSize: 12, color: over ? ArcaneTheme.tertiary : ArcaneTheme.primary)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        // Quick Stat Presets Row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.casino_rounded, size: 16, color: ArcaneTheme.secondary),
                label: Text('Roll 4d6 Dice', style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: ArcaneTheme.secondary.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () => _rollAll(context, ref),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: Text('Standard Array', style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ArcaneTheme.primary.withValues(alpha: 0.25),
                  foregroundColor: ArcaneTheme.primary,
                  side: BorderSide(color: ArcaneTheme.primary.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () => _applyStandardArray(context, ref, draft.charClass),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...[
          ('STR', abilities.str, (v) => abilities.copyWith(str: v), abilities.strMod, 'Melee, carry'),
          ('DEX', abilities.dex, (v) => abilities.copyWith(dex: v), abilities.dexMod, 'AC, finesse'),
          ('CON', abilities.con, (v) => abilities.copyWith(con: v), abilities.conMod, 'HP, resilience'),
          ('INT', abilities.int_, (v) => abilities.copyWith(int_: v), abilities.intMod, 'Knowledge, spells'),
          ('WIS', abilities.wis, (v) => abilities.copyWith(wis: v), abilities.wisMod, 'Perception, will'),
          ('CHA', abilities.cha, (v) => abilities.copyWith(cha: v), abilities.chaMod, 'Charm, leadership'),
        ].map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: ArcaneTheme.cardDecoration(),
                child: Row(children: [
                  SizedBox(width: 44, child: Text(e.$1, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.$5, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                    color: e.$2 > 8 ? ArcaneTheme.primary : ArcaneTheme.textMuted.withOpacity(0.4),
                    onPressed: e.$2 > 8
                        ? () {
                            final next = e.$2 - 1;
                            // Only allow if would still be valid cost? Actually lowering always reduces cost, so allowed.
                            ref.read(characterDraftProvider.notifier).setAbilities(e.$3(next));
                          }
                        : null,
                  ),
                  Container(
                    width: 48,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: ArcaneTheme.border)),
                    child: Column(children: [
                      Text('${e.$2}', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                      Text('${e.$4 >= 0 ? '+' : ''}${e.$4}', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textSecondary)),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, size: 22),
                    color: e.$2 < 15 ? ArcaneTheme.primary : ArcaneTheme.textMuted.withOpacity(0.4),
                    onPressed: e.$2 < 15
                        ? () {
                            final attempted = e.$3(e.$2 + 1);
                            if (attempted.totalCost() <= 27) {
                              ref.read(characterDraftProvider.notifier).setAbilities(attempted);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not enough points — ${attempted.totalCost()} / 27', style: GoogleFonts.ibmPlexSans()), backgroundColor: ArcaneTheme.tertiary, duration: const Duration(seconds: 1)));
                            }
                          }
                        : null,
                  ),
                ]),
              ),
            )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _DerivedStat('HP', '${_hpPreview(draft)}', Icons.favorite_rounded, ArcaneTheme.tertiary),
            _DerivedStat('AC', '${10 + abilities.dexMod}', Icons.shield_rounded, ArcaneTheme.secondary),
            _DerivedStat('Cost', '$cost/27', Icons.calculate_rounded, over ? ArcaneTheme.tertiary : ArcaneTheme.primary),
          ]),
        ),
        const SizedBox(height: 10),
        Text('Racial bonuses (+1/+2) apply after this allocation and may push a score to 16–17.', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
      ],
    );
  }

  int _hpPreview(CharacterDraft draft) {
    final int con = draft.abilities.conMod;
    final int die = {'d6': 6, 'd8': 8, 'd10': 10, 'd12': 12}[draft.charClass.hitDie] ?? 8;
    return die + con;
  }
}

class _DerivedStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _DerivedStat(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, size: 16, color: color)),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
      Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
    ]);
  }
}
