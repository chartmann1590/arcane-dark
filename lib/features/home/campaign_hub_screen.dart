import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../providers/campaign_provider.dart';
import '../../providers/character_provider.dart';
import '../../domain/campaign_seed.dart';
import '../../services/ad_service.dart';

class CampaignHubScreen extends ConsumerWidget {
  const CampaignHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(campaignProvider);
    final chars = ref.watch(savedCharactersProvider);
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(
        title: Text('ARCANE DARK', style: GoogleFonts.playfairDisplay(color: ArcaneTheme.secondary, letterSpacing: 2, fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Current Campaign card — matches Stitch Campaign Hub screenshot
          if (campaign != null) ...[
            Container(
              decoration: ArcaneTheme.cardDecoration(goldBorder: true),
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
                            child: Text('CURRENT CAMPAIGN', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: ArcaneTheme.primary)),
                          ),
                          const Spacer(),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ArcaneTheme.secondary.withOpacity(0.4)),
                              image: const DecorationImage(
                                image: NetworkImage('https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=200'),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: ArcaneTheme.secondary, borderRadius: BorderRadius.circular(4)),
                                child: Text('LVL ${campaign.party.length}', style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(campaign.seed.title, style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                      const SizedBox(height: 6),
                      Text(campaign.seed.hook, style: GoogleFonts.manrope(fontSize: 13, color: ArcaneTheme.textSecondary, height: 1.4)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/play'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A2440), foregroundColor: ArcaneTheme.secondary, side: BorderSide(color: ArcaneTheme.secondary.withOpacity(0.5))),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('RESUME', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1)),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward, size: 16),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
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
                  Text('No Active Campaign', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Create a hero and forge your first legend. The AI Dungeon Master awaits.', textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 13, color: ArcaneTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _ActionCard(
            icon: Icons.add_rounded,
            iconBg: ArcaneTheme.primary.withOpacity(0.15),
            iconColor: ArcaneTheme.primary,
            title: 'New Solo Campaign',
            subtitle: chars.isEmpty ? 'Create a hero first' : 'Start a fresh journey',
            onTap: () {
              if (chars.isEmpty) {
                context.go('/heroes');
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
            Text('YOUR HEROES', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: ArcaneTheme.textMuted)),
            const SizedBox(height: 10),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chars.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (c, i) {
                  final ch = chars[i];
                  return Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: ArcaneTheme.cardDecoration(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(radius: 16, backgroundColor: ArcaneTheme.primary.withOpacity(0.2), child: Text(ch.name.isNotEmpty ? ch.name[0].toUpperCase() : '?', style: GoogleFonts.playfairDisplay(color: ArcaneTheme.primary, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
                      ]),
                      const SizedBox(height: 6),
                      Text('${ch.race.label} • ${ch.charClass.label}', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _StatChip('HP ${ch.hp}'),
                        const SizedBox(width: 6),
                        _StatChip('AC ${ch.armorClass}'),
                      ]),
                    ]),
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
                Expanded(child: Text('Tip: Head to Heroes to build your first character — race, class, abilities & a live portrait editor.', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary))),
              ]),
            ),
        ],
      ),
    );
  }

  void _showCampaignPicker(BuildContext context, WidgetRef ref, chars) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Choose a Legend', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          ...CampaignSeed.presets.map((seed) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(c);
                    ref.read(campaignProvider.notifier).startNew(seed, chars);
                    context.go('/play');
                    InterstitialAdManager.instance.showIfReady();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: ArcaneTheme.cardDecoration(),
                    child: Row(children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: ArcaneTheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.map_rounded, color: ArcaneTheme.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(seed.title, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(seed.hook, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(seed.tone, style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.secondary, fontWeight: FontWeight.w600)),
                      ])),
                    ]),
                  ),
                ),
              )),
        ]),
      ),
    );
  }
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.border)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            Text(subtitle, style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary)),
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
      child: Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: ArcaneTheme.textMuted)),
    );
  }
}
