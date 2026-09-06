import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../providers/campaign_provider.dart';
import '../../providers/character_provider.dart';
import '../../domain/campaign_seed.dart';
import '../../domain/campaign_state.dart';
import '../../domain/character.dart';
import '../../widgets/fx.dart';
import '../../widgets/party_assembler_sheet.dart';

class CampaignHubScreen extends ConsumerWidget {
  const CampaignHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(campaignProvider);
    final chars = ref.watch(savedCharactersProvider);
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(
        title: Text('ARCANE DARK', style: GoogleFonts.cinzel(color: ArcaneTheme.secondary, letterSpacing: 2, fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Current Campaign card — matches Stitch Campaign Hub screenshot
          if (campaign != null) ...[
            PopIn(child: Container(
              decoration: ArcaneTheme.ornateDecoration(),
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ArcaneTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ArcaneTheme.primary.withOpacity(0.3)),
                            ),
                            child: Text('CURRENT CAMPAIGN', style: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: ArcaneTheme.primary)),
                          ),
                          const Spacer(),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ArcaneTheme.secondary.withOpacity(0.4)),
                              image: DecorationImage(
                                image: AssetImage('assets/avatar/portraits/${_leaderRace(campaign, chars)}.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: ArcaneTheme.secondary, borderRadius: BorderRadius.circular(4)),
                                child: Text('LVL ${campaign.party.length}', style: GoogleFonts.ibmPlexSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(campaign.seed.title, style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                      const SizedBox(height: 6),
                      Text(campaign.seed.hook, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: ArcaneTheme.textSecondary, height: 1.4)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/play'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A2440), foregroundColor: ArcaneTheme.secondary, side: BorderSide(color: ArcaneTheme.secondary.withOpacity(0.5))),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('RESUME', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800, letterSpacing: 1)),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward, size: 16),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
          ] else ...[
            PopIn(
              child: Container(
                decoration: BoxDecoration(
                  color: ArcaneTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ArcaneTheme.border),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: ArcaneTheme.primary.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.auto_stories_rounded, color: ArcaneTheme.primary, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text('No Active Campaign', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Create a hero and forge your first legend. The AI Dungeon Master awaits.', textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: ArcaneTheme.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          _ActionCard(
            icon: Icons.shield_moon_rounded,
            iconBg: ArcaneTheme.primary.withOpacity(0.15),
            iconColor: ArcaneTheme.primary,
            title: 'New Offline Campaign',
            subtitle: chars.isEmpty ? 'Create a hero first' : 'Assemble party with AI companions',
            onTap: () {
              if (chars.isEmpty) {
                context.push('/create');
              } else {
                _showCampaignPicker(context, ref, chars);
              }
            },
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.groups_rounded,
            iconBg: ArcaneTheme.secondary.withOpacity(0.12),
            iconColor: ArcaneTheme.secondary,
            title: 'Multiplayer',
            subtitle: 'Join or Host',
            onTap: () => context.go('/party'),
          ),
          const SizedBox(height: 20),

          // Quick party preview
          if (chars.isNotEmpty) ...[
            Text('YOUR HEROES', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: ArcaneTheme.textMuted)),
            const SizedBox(height: 10),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chars.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (c, i) {
                  final ch = chars[i];
                  return PopIn(
                    delay: Duration(milliseconds: 60 * i),
                    child: PressableScale(
                      onTap: () => context.push('/heroes/${ch.id}'),
                      child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: ArcaneTheme.cardDecoration(),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleAvatar(radius: 16, backgroundColor: ArcaneTheme.primary.withOpacity(0.2), backgroundImage: AssetImage('assets/avatar/portraits/${ch.race.name}.png')),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
                        ]),
                        const SizedBox(height: 6),
                        Text('${ch.race.label} • ${ch.charClass.label}', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Row(children: [
                          _StatChip('HP ${ch.hp}'),
                          const SizedBox(width: 6),
                          _StatChip('AC ${ch.armorClass}'),
                        ]),
                      ]),
                    )),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 24),
          // Onboarding hint
          if (chars.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ArcaneTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.primary.withOpacity(0.18))),
              child: Row(children: [
                const Icon(Icons.lightbulb_rounded, color: ArcaneTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Tip: Head to Heroes to build your first character — race, class, abilities & a live portrait editor.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary))),
              ]),
            ),
        ],
      ),
    );
  }

  void _showCampaignPicker(BuildContext context, WidgetRef ref, List<Character> chars) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: ArcaneTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('CHOOSE A LEGEND', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Select an adventure setting, then assemble your party of heroes.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
            const SizedBox(height: 16),
            ...CampaignSeed.presets.map((seed) {
              final (icon, col) = switch (seed.id) {
                'ember_wastes' => (Icons.local_fire_department_rounded, Colors.deepOrangeAccent),
                'frostpeak_spire' => (Icons.ac_unit_rounded, Colors.cyanAccent),
                'sunken_citadel' => (Icons.water_rounded, Colors.lightBlueAccent),
                _ => (Icons.shield_moon_rounded, ArcaneTheme.primary),
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(c);
                    showPartyAssembler(
                      context: context,
                      ref: ref,
                      seed: seed,
                      playerCharacters: chars,
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: ArcaneTheme.cardDecoration(),
                    child: Row(children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: col.withValues(alpha: 0.3))),
                        child: Icon(icon, color: col, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(seed.title, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(seed.hook, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: col.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                child: Text(seed.tone, style: GoogleFonts.ibmPlexSans(fontSize: 10.5, color: col, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('•  ${seed.setting}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: Colors.white38)),
                              ),
                            ],
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

String _leaderRace(CampaignState campaign, List<Character> chars) {
  if (campaign.party.isEmpty) return Race.human.name;
  final leaderId = campaign.party.first.characterId;
  for (final c in chars) {
    if (c.id == leaderId) return c.race.name;
  }
  return Race.human.name;
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.iconBg, required this.iconColor, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.border)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            Text(subtitle, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: ArcaneTheme.textMuted),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(6), border: Border.all(color: ArcaneTheme.border)),
      child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w700, color: ArcaneTheme.textMuted)),
    );
  }
}
