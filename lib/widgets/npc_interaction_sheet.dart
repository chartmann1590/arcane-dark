import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../domain/campaign_state.dart';
import '../features/play/tavern_populator.dart';
import '../services/audio_service.dart';

class NpcInteractionSheet extends StatefulWidget {
  final MapNpc npc;
  final CampaignState campaign;
  final void Function(String prompt) onConverse;
  final void Function(String item) onBuyItem;
  final void Function(int healAmount) onHealParty;
  final void Function(MapNpc npc) onRecruit;
  final void Function(MapNpc hostileNpc) onChallenge;

  const NpcInteractionSheet({
    super.key,
    required this.npc,
    required this.campaign,
    required this.onConverse,
    required this.onBuyItem,
    required this.onHealParty,
    required this.onRecruit,
    required this.onChallenge,
  });

  @override
  State<NpcInteractionSheet> createState() => _NpcInteractionSheetState();
}

class _NpcInteractionSheetState extends State<NpcInteractionSheet> {
  String? _statusBanner;
  bool _isSuccessBanner = true;

  void _showBanner(String message, {bool success = true}) {
    setState(() {
      _statusBanner = message;
      _isSuccessBanner = success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final npc = widget.npc;
    final partyCount = widget.campaign.party.length;
    final canRecruit = npc.canRecruit && partyCount < 4;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF14161F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.15),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // NPC Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ArcaneTheme.secondary, width: 2.2),
                  image: DecorationImage(
                    image: AssetImage(npc.portraitAsset),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ArcaneTheme.secondary.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      npc.name.toUpperCase(),
                      style: GoogleFonts.cinzel(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber.shade200,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: ArcaneTheme.secondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.6), width: 0.8),
                          ),
                          child: Text(
                            npc.role,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ArcaneTheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Wandering Encounter',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Speech Bubble
          if (npc.greeting != null && npc.greeting!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, size: 20, color: ArcaneTheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      npc.greeting!,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_statusBanner != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isSuccessBanner
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isSuccessBanner ? Colors.greenAccent : Colors.redAccent,
                  width: 1,
                ),
              ),
              child: Text(
                _statusBanner!,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Scrollable Actions
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // Inquire & Converse Options
                Text(
                  'CONVERSATION TOPICS',
                  style: GoogleFonts.cinzel(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ArcaneTheme.secondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                for (final option in (npc.dialogueOptions.isNotEmpty
                    ? npc.dialogueOptions
                    : ['What rumors have you heard in these catacombs?']))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () {
                        AudioService.instance.playTap();
                        Navigator.pop(context);
                        widget.onConverse('I speak with ${npc.name}: "$option"');
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: ArcaneTheme.secondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                option,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white38),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Trading & Wares
                if (npc.shopItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'MERCHANT WARES',
                    style: GoogleFonts.cinzel(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ArcaneTheme.secondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final item in npc.shopItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.amberAccent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.amberAccent,
                                side: const BorderSide(color: Colors.amberAccent),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () {
                                AudioService.instance.playSuccess();
                                widget.onBuyItem(item);
                                _showBanner('Purchased $item! Added to party inventory.');
                              },
                              child: Text(
                                'Buy (20g)',
                                style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],

                // Healer Blessing
                if (npc.healPower > 0) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.favorite_rounded, size: 18, color: Colors.greenAccent),
                    label: Text(
                      'Request Blessing & Healing (+${npc.healPower} HP)',
                      style: GoogleFonts.ibmPlexSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.25),
                      foregroundColor: Colors.greenAccent,
                      side: const BorderSide(color: Colors.greenAccent),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: () {
                      AudioService.instance.playSuccess();
                      widget.onHealParty(npc.healPower);
                      _showBanner('${npc.name} channels sacred grace! Restored +${npc.healPower} HP to party.');
                    },
                  ),
                ],

                // Party Recruitment
                if (npc.canRecruit) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.group_add_rounded, size: 18),
                    label: Text(
                      canRecruit
                          ? 'Recruit ${npc.name} to Party ($partyCount/4)'
                          : 'Party is Full ($partyCount/4 Adventurers)',
                      style: GoogleFonts.ibmPlexSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canRecruit
                          ? ArcaneTheme.primary.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.2),
                      foregroundColor: canRecruit ? Colors.white : Colors.white38,
                      side: BorderSide(color: canRecruit ? ArcaneTheme.primary : Colors.white12),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: canRecruit
                        ? () {
                            AudioService.instance.playSuccess();
                            Navigator.pop(context);
                            widget.onRecruit(npc);
                          }
                        : null,
                  ),
                ],

                const SizedBox(height: 12),

                // Challenge / Attack option
                OutlinedButton.icon(
                  icon: const Icon(Icons.shield_outlined, size: 16, color: Colors.redAccent),
                  label: Text(
                    'Draw Steel & Challenge (Initiate Combat)',
                    style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    final hostileNpc = npc.copyWith(isHostile: true);
                    widget.onChallenge(hostileNpc);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
