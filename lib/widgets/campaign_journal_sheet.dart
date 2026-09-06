import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../domain/campaign_state.dart';
import '../services/audio_service.dart';
import 'fx.dart';

class CampaignJournalSheet extends StatefulWidget {
  final CampaignState campaign;
  final void Function(int restoredHp) onLongRestCompleted;
  final void Function(String narration) onRestNarration;

  const CampaignJournalSheet({
    super.key,
    required this.campaign,
    required this.onLongRestCompleted,
    required this.onRestNarration,
  });

  @override
  State<CampaignJournalSheet> createState() => _CampaignJournalSheetState();
}

class _CampaignJournalSheetState extends State<CampaignJournalSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: ArcaneTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: ArcaneTheme.secondary.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ArcaneTheme.secondary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: ArcaneTheme.secondary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CAMPAIGN CODEX',
                        style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2),
                      ),
                      Text(
                        widget.campaign.seed.title,
                        style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: ArcaneTheme.secondary,
            labelColor: ArcaneTheme.secondary,
            unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(icon: Icon(Icons.menu_book_rounded, size: 16), text: 'Chronicles'),
              Tab(icon: Icon(Icons.group_rounded, size: 16), text: 'Fellowship'),
              Tab(icon: Icon(Icons.pets_rounded, size: 16), text: 'Bestiary'),
              Tab(icon: Icon(Icons.nightlight_round, size: 16), text: 'Camp & Rest'),
            ],
          ),

          const Divider(height: 1, color: Colors.white12),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChroniclesTab(),
                _buildFellowshipTab(),
                _buildBestiaryTab(),
                _buildCampTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChroniclesTab() {
    final quests = widget.campaign.questLog;
    final depth = widget.campaign.worldFlags['dungeonDepth'] as int? ?? 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Primary Campaign Objective Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ArcaneTheme.primary.withValues(alpha: 0.3),
                ArcaneTheme.surfaceElevated,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ArcaneTheme.primary.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_rounded, color: ArcaneTheme.secondary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'PRIMARY MISSION: DEPTH $depth',
                    style: GoogleFonts.cinzel(fontSize: 13, fontWeight: FontWeight.w800, color: ArcaneTheme.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Explore the subterranean labyrinth, eliminate hostile sentries, and uncover the ancient relic guarded in the depths.',
                style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _statusBadge('Floor: $depth', Icons.layers_rounded, ArcaneTheme.secondary),
                  _statusBadge('Threat: Moderate', Icons.warning_amber_rounded, Colors.orangeAccent),
                  _statusBadge('Reward: 250 GP + Rare Artifact', Icons.stars_rounded, Colors.amberAccent),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Text('ACTIVE QUEST OBJECTIVES', style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),

        if (quests.isEmpty) ...[
          _questItem(
            title: 'Clear the Perimeter Guards',
            stage: 'Engage and defeat roaming skeleton sentries and goblin raiders.',
            isComplete: false,
          ),
          _questItem(
            title: 'Search for the Relic Coffer',
            stage: 'Inspect locked chests in the crypt chambers.',
            isComplete: false,
          ),
          _questItem(
            title: 'Descend to Lower Levels',
            stage: 'Locate the stairs descending into Dungeon Depth ${depth + 1}.',
            isComplete: false,
          ),
        ] else ...[
          for (final q in quests)
            _questItem(
              title: q.title,
              stage: q.stage,
              isComplete: q.status == 'completed',
            ),
        ],

        if (widget.campaign.sidequests.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('REALM SIDEQUESTS & BOUNTIES', style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: ArcaneTheme.secondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  '${widget.campaign.sidequests.where((s) => s.isCompleted).length}/${widget.campaign.sidequests.length} Completed',
                  style: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final sq in widget.campaign.sidequests)
            _sidequestItem(sq),
        ],
      ],
    );
  }

  Widget _sidequestItem(Sidequest sq) {
    final catIcon = switch (sq.category) {
      'combat' => Icons.sports_kabaddi_rounded,
      'puzzle' => Icons.extension_rounded,
      'scavenge' => Icons.inventory_2_rounded,
      _ => Icons.explore_rounded,
    };
    final catColor = switch (sq.category) {
      'combat' => const Color(0xFFE53935),
      'puzzle' => const Color(0xFFAB47BC),
      'scavenge' => const Color(0xFFFFB300),
      _ => const Color(0xFF42A5F5),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArcaneTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sq.isCompleted ? Colors.green.withValues(alpha: 0.5) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: catColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Icon(catIcon, size: 14, color: catColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sq.title,
                  style: GoogleFonts.cinzel(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sq.isCompleted ? Colors.white60 : Colors.white,
                    decoration: sq.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Icon(
                sq.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: sq.isCompleted ? Colors.greenAccent : Colors.white30,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sq.objective,
            style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, size: 12, color: Colors.amberAccent),
                const SizedBox(width: 4),
                Text(
                  sq.rewardDescription,
                  style: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amberAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questItem({required String title, required String stage, required bool isComplete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArcaneTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isComplete ? Colors.green.withValues(alpha: 0.5) : Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isComplete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isComplete ? Colors.greenAccent : ArcaneTheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cinzel(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isComplete ? Colors.white60 : Colors.white,
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stage,
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFellowshipTab() {
    final party = widget.campaign.party;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: party.length,
      itemBuilder: (ctx, i) {
        final hero = party[i];
        final isLeader = i == 0;
        final hpRatio = (hero.hp / max(1, hero.maxHp)).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ArcaneTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLeader ? ArcaneTheme.primary.withValues(alpha: 0.6) : Colors.white12,
              width: isLeader ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isLeader ? ArcaneTheme.primary : ArcaneTheme.secondary, width: 2),
                      color: ArcaneTheme.surface,
                    ),
                    child: Center(
                      child: Icon(
                        isLeader ? Icons.person_rounded : Icons.shield_rounded,
                        color: isLeader ? ArcaneTheme.primary : ArcaneTheme.secondary,
                        size: 24,
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
                              hero.name,
                              style: GoogleFonts.cinzel(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            if (isLeader) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(color: ArcaneTheme.primary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
                                child: Text('LEAD', style: GoogleFonts.ibmPlexSans(fontSize: 9, fontWeight: FontWeight.w700, color: ArcaneTheme.primary)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${hero.raceLabel} • ${hero.classLabel} (Level 1)',
                          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text('AC ${hero.armorClass}', style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w800, color: ArcaneTheme.secondary)),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // HP Bar
              Row(
                children: [
                  Text('HP', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: hpRatio,
                        backgroundColor: Colors.black45,
                        valueColor: AlwaysStoppedAnimation(hpRatio > 0.4 ? const Color(0xFF3DD68C) : Colors.redAccent),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${hero.hp} / ${hero.maxHp}', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: Colors.white70)),
                ],
              ),

              if (hero.persona.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '"${hero.persona}"',
                  style: GoogleFonts.ibmPlexSans(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white54),
                ),
              ],

              if (hero.inventory.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final item in hero.inventory.take(4))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(item, style: GoogleFonts.ibmPlexSans(fontSize: 10, color: Colors.white70)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBestiaryTab() {
    const monsters = [
      (
        name: 'Skeleton Sentry',
        role: 'Undead Guardian',
        ac: 13,
        hp: 12,
        attack: 'Rusted Scythe (1d6+2)',
        asset: 'assets/tiles/prop_bones.png',
        desc: 'Reanimated bones bound by necrotic energy. Resilient against piercing, vulnerable to bludgeoning.',
      ),
      (
        name: 'Goblin Skulker',
        role: 'Cave Raider',
        ac: 14,
        hp: 10,
        attack: 'Jagged Dagger (1d6+2)',
        asset: 'assets/avatar/portraits/halfling.png',
        desc: 'Quick and vicious scavengers lurking in dark crevices. Relies on agility and surprise ambush.',
      ),
      (
        name: 'Orc Marauder',
        role: 'Subterranean Brute',
        ac: 13,
        hp: 18,
        attack: 'Iron Cleaver (1d8+3)',
        asset: 'assets/avatar/portraits/orc.png',
        desc: 'Heavily muscled dungeon vanguard capable of ferocious cleaving swings.',
      ),
      (
        name: 'Shadow Cultist',
        role: 'Acolyte of Darkness',
        ac: 12,
        hp: 14,
        attack: 'Dark Pulse (1d8+2)',
        asset: 'assets/avatar/portraits/tiefling.png',
        desc: 'Fanatics devoted to the sealed horror beneath the crypt. Chants fell cantrips from the shadows.',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: monsters.length,
      itemBuilder: (ctx, i) {
        final m = monsters[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ArcaneTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 1.5),
                  image: DecorationImage(image: AssetImage(m.asset), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(m.name, style: GoogleFonts.cinzel(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                          child: Text('AC ${m.ac} • ${m.hp} HP', style: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.redAccent)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(m.role, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.secondary)),
                    const SizedBox(height: 6),
                    Text(m.desc, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: Colors.white60, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCampTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ArcaneTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Pulse(
                  child: Icon(Icons.fireplace_rounded, color: Colors.amberAccent, size: 48),
                ),
                const SizedBox(height: 12),
                Text(
                  'SANCTUARY & LONG REST',
                  style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'The party beds down in a secure alcove. A long rest restores all party members to maximum Hit Points and replenishes spell energy. Nighttime sentry watches are set.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.bedtime_rounded, size: 20),
            label: const Text('Establish Camp & Long Rest (Full Restore)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3DD68C),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              var totalRestored = 0;
              for (final m in widget.campaign.party) {
                totalRestored += (m.maxHp - m.hp);
                m.hp = m.maxHp;
              }
              widget.onLongRestCompleted(totalRestored);
              AudioService.instance.playSuccess();
              widget.onRestNarration(
                'The party establishes camp around a crackling hearth. After a restful 8 hours of sleep and watchful sentry duty, the party awakens fully refreshed (all HP restored)!',
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
