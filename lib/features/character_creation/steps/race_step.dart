import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../domain/character.dart';
import '../../../providers/character_provider.dart';

class RaceStep extends ConsumerWidget {
  const RaceStep({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('Choose your lineage — it shapes your abilities and story.', style: GoogleFonts.manrope(fontSize: 13, color: ArcaneTheme.textSecondary)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1),
          itemCount: Race.values.length,
          itemBuilder: (c, i) {
            final race = Race.values[i];
            final selected = draft.race == race;
            return InkWell(
              onTap: () => ref.read(characterDraftProvider.notifier).setRace(race),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: ArcaneTheme.cardDecoration(selected: selected, goldBorder: false),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: selected ? ArcaneTheme.primary.withOpacity(0.2) : ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(8)),
                      child: Icon(_iconForRace(race), color: selected ? ArcaneTheme.primary : ArcaneTheme.textMuted, size: 20),
                    ),
                    const Spacer(),
                    if (selected) const Icon(Icons.check_circle_rounded, color: ArcaneTheme.primary, size: 18),
                  ]),
                  const SizedBox(height: 10),
                  Text(race.label, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(race.bonus, style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.secondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Expanded(child: Text(race.flavor, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textSecondary, height: 1.3))),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _iconForRace(Race r) => switch (r) {
        Race.human => Icons.person_rounded,
        Race.elf => Icons.eco_rounded,
        Race.dwarf => Icons.fort_rounded,
        Race.halfling => Icons.child_care_rounded,
        Race.orc => Icons.shield_rounded,
        Race.tiefling => Icons.local_fire_department_rounded,
        Race.dragonborn => Icons.whatshot_rounded,
      };
}
