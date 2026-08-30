import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../domain/character.dart';
import '../../../providers/character_provider.dart';

class BackgroundStep extends ConsumerWidget {
  const BackgroundStep({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('Where you came from colors every bond and flaw.', style: GoogleFonts.manrope(fontSize: 13, color: ArcaneTheme.textSecondary)),
        const SizedBox(height: 14),
        ...Background.values.map((bg) {
          final selected = draft.background == bg;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => ref.read(characterDraftProvider.notifier).setBackground(bg),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: ArcaneTheme.cardDecoration(selected: selected),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(bg.label, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(bg.flavor, style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary)),
                  ])),
                  if (selected) const Icon(Icons.check_circle_rounded, color: ArcaneTheme.primary),
                ]),
              ),
            ),
          );
        }),
      ],
    );
  }
}
