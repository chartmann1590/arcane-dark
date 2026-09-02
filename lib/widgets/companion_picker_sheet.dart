import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../domain/companion_templates.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../services/audio_service.dart';

/// A bottom sheet offering pre-built AI companions — for solo players who
/// want a fuller party without hand-building every character. Recruiting one
/// adds it as an ordinary saved Character (same personas, same voice picker)
/// AND, if a campaign is already underway, drops them straight into its
/// party so they join the story immediately rather than only showing up in
/// campaigns started afterward.
void showCompanionPicker(BuildContext context, WidgetRef ref) {
  final existingNames = ref.read(savedCharactersProvider).map((c) => c.name).toSet();
  showModalBottomSheet(
    context: context,
    backgroundColor: ArcaneTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recruit a Companion', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('AI-played heroes ready to join your party — no character creation needed.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              itemCount: companionTemplates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (c, i) {
                final t = companionTemplates[i];
                final alreadyRecruited = existingNames.contains(t.name);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: ArcaneTheme.cardDecoration(),
                  child: Row(children: [
                    CircleAvatar(radius: 26, backgroundColor: ArcaneTheme.primary.withOpacity(0.15), backgroundImage: AssetImage('assets/avatar/portraits/${t.race.name}.png')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.name, style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('${t.race.label} • ${t.charClass.label}', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.secondary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(t.tagline, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textSecondary, height: 1.3)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    alreadyRecruited
                        ? Icon(Icons.check_circle_rounded, color: ArcaneTheme.secondary, size: 22)
                        : OutlinedButton(
                            onPressed: () async {
                              final companion = t.toCharacter();
                              await ref.read(savedCharactersProvider.notifier).add(companion);
                              final joinedCampaign = ref.read(campaignProvider) != null;
                              if (joinedCampaign) ref.read(campaignProvider.notifier).addPartyMember(companion);
                              AudioService.instance.playSuccess();
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                                  content: Text(joinedCampaign ? '${t.name} joins your roster — and your current party!' : '${t.name} joins your roster!', style: GoogleFonts.ibmPlexSans()),
                                  backgroundColor: ArcaneTheme.primary,
                                ));
                              }
                            },
                            child: Text('Recruit', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    ),
  );
}
