import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../domain/character.dart';
import '../../../providers/character_provider.dart';

class ClassStep extends ConsumerWidget {
  const ClassStep({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('Your class defines how you face danger — steel, spell, or shadow.', style: GoogleFonts.manrope(fontSize: 13, color: ArcaneTheme.textSecondary)),
        const SizedBox(height: 14),
        ...CharClass.values.map((cls) {
          final selected = draft.charClass == cls;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => ref.read(characterDraftProvider.notifier).setClass(cls),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: ArcaneTheme.cardDecoration(selected: selected),
                child: Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: selected ? ArcaneTheme.primary.withOpacity(0.18) : ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(10)), child: Icon(_iconForClass(cls), color: selected ? ArcaneTheme.primary : ArcaneTheme.textMuted)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(cls.label, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(6), border: Border.all(color: ArcaneTheme.border)), child: Text(cls.hitDie, style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 4),
                    Text(cls.flavor, style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary, height: 1.3)),
                  ])),
                  if (selected) const Icon(Icons.check_circle_rounded, color: ArcaneTheme.primary, size: 20),
                ]),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _iconForClass(CharClass c) => switch (c) {
        CharClass.fighter => Icons.security_rounded,
        CharClass.wizard => Icons.auto_fix_high_rounded,
        CharClass.rogue => Icons.visibility_off_rounded,
        CharClass.cleric => Icons.favorite_rounded,
        CharClass.ranger => Icons.park_rounded,
        CharClass.bard => Icons.music_note_rounded,
        CharClass.barbarian => Icons.storm_rounded,
        CharClass.paladin => Icons.shield_rounded,
      };
}
