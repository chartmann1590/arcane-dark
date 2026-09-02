import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../providers/character_provider.dart';
import '../../widgets/companion_picker_sheet.dart';
import '../../widgets/fx.dart';

class HeroesRosterScreen extends ConsumerWidget {
  const HeroesRosterScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(savedCharactersProvider);
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(
        title: Text('YOUR HEROES', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 13)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.group_add_rounded), tooltip: 'Recruit a Companion', onPressed: () => showCompanionPicker(context, ref)),
          IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'New Hero', onPressed: () => context.push('/create')),
        ],
      ),
      body: chars.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: ArcaneTheme.primary.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.person_add_alt_1_rounded, color: ArcaneTheme.primary, size: 28)),
                  const SizedBox(height: 16),
                  Text('No heroes yet', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Create your first character, or recruit an AI companion to play alongside you.', textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: ArcaneTheme.textSecondary)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(onPressed: () => context.push('/create'), icon: const Icon(Icons.add_rounded, size: 18), label: Text('Create a Hero', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700))),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: () => showCompanionPicker(context, ref), icon: const Icon(Icons.group_add_rounded, size: 18), label: Text('Recruit a Companion', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700))),
                ]),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: chars.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (c, i) {
                final ch = chars[i];
                return PopIn(
                  delay: Duration(milliseconds: 60 * i),
                  child: PressableScale(
                    onTap: () => context.push('/heroes/${ch.id}'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: ArcaneTheme.cardDecoration(),
                      child: Row(children: [
                        CircleAvatar(radius: 28, backgroundColor: ArcaneTheme.primary.withOpacity(0.15), backgroundImage: AssetImage('assets/avatar/portraits/${ch.race.name}.png')),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(ch.name, style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text('${ch.race.label} • ${ch.charClass.label} • Lv ${ch.level}', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
                            const SizedBox(height: 6),
                            Row(children: [
                              _StatChip('HP ${ch.hp}', ArcaneTheme.tertiary),
                              const SizedBox(width: 6),
                              _StatChip('AC ${ch.armorClass}', ArcaneTheme.secondary),
                            ]),
                          ]),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: ArcaneTheme.textMuted),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
