import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../providers/character_provider.dart';
import '../../../services/ad_service.dart';
import '../../../services/audio_service.dart';

class ReviewStep extends ConsumerWidget {
  const ReviewStep({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    final hp = draft.toCharacter().hp;
    final ac = draft.toCharacter().armorClass;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Container(
          decoration: ArcaneTheme.cardDecoration(goldBorder: true),
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            CircleAvatar(radius: 36, backgroundColor: ArcaneTheme.primary.withOpacity(0.15), backgroundImage: AssetImage('assets/avatar/portraits/${draft.race.name}.png')),
            const SizedBox(height: 12),
            Text(draft.name.isEmpty ? 'Unnamed Hero' : draft.name, style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('${draft.race.label} • ${draft.charClass.label} • ${draft.background.label}', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Pill('HP $hp', ArcaneTheme.tertiary),
              const SizedBox(width: 8),
              _Pill('AC $ac', ArcaneTheme.secondary),
              const SizedBox(width: 8),
              _Pill(draft.charClass.hitDie, ArcaneTheme.primary),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: ArcaneTheme.cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ABILITY SCORES', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: ArcaneTheme.textMuted)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ScoreChip('STR', draft.abilities.str),
              _ScoreChip('DEX', draft.abilities.dex),
              _ScoreChip('CON', draft.abilities.con),
              _ScoreChip('INT', draft.abilities.int_),
              _ScoreChip('WIS', draft.abilities.wis),
              _ScoreChip('CHA', draft.abilities.cha),
            ]),
            const SizedBox(height: 8),
            Text('Modifiers: STR ${draft.abilities.strMod >= 0 ? '+' : ''}${draft.abilities.strMod}  DEX ${draft.abilities.dexMod >= 0 ? '+' : ''}${draft.abilities.dexMod}  CON ${draft.abilities.conMod >= 0 ? '+' : ''}${draft.abilities.conMod}  INT ${draft.abilities.intMod >= 0 ? '+' : ''}${draft.abilities.intMod}  WIS ${draft.abilities.wisMod >= 0 ? '+' : ''}${draft.abilities.wisMod}  CHA ${draft.abilities.chaMod >= 0 ? '+' : ''}${draft.abilities.chaMod}', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted)),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final char = draft.toCharacter();
              await ref.read(savedCharactersProvider.notifier).add(char);
              ref.read(characterDraftProvider.notifier).reset();
              AudioService.instance.playSuccess();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${char.name} created — ready for adventure!', style: GoogleFonts.manrope()), backgroundColor: ArcaneTheme.primary));
                context.go('/home');
              }
              InterstitialAdManager.instance.showIfReady();
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text('Create Character', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
        const SizedBox(height: 8),
        Text('Saves locally (offline). Will sync to Firestore when you join a party.', textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))), child: Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: color)));
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int score;
  const _ScoreChip(this.label, this.score);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: ArcaneTheme.border)),
      child: Column(children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: ArcaneTheme.textMuted, letterSpacing: 0.8)),
        Text('$score', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
    );
  }
}
