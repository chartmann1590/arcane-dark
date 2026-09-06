import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../domain/campaign_state.dart';
import '../domain/character.dart';
import '../domain/pet_companion.dart';
import '../domain/world_location.dart';
import '../services/audio_service.dart';

/// Full-screen fantasy cinematic fast travel sequence displaying departure &
/// destination realms, full party roster, active pet companion, animated journey
/// progression, and atmospheric travel lore.
class FastTravelSequenceDialog extends StatefulWidget {
  final WorldLocation origin;
  final WorldLocation destination;
  final List<PartyMemberStatus> party;
  final List<Character> savedCharacters;
  final PetCompanion? activePet;
  final VoidCallback onComplete;

  const FastTravelSequenceDialog({
    super.key,
    required this.origin,
    required this.destination,
    required this.party,
    required this.savedCharacters,
    this.activePet,
    required this.onComplete,
  });

  static Future<void> show({
    required BuildContext context,
    required WorldLocation origin,
    required WorldLocation destination,
    required List<PartyMemberStatus> party,
    required List<Character> savedCharacters,
    PetCompanion? activePet,
    required VoidCallback onComplete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => FastTravelSequenceDialog(
        origin: origin,
        destination: destination,
        party: party,
        savedCharacters: savedCharacters,
        activePet: activePet,
        onComplete: onComplete,
      ),
    );
  }

  @override
  State<FastTravelSequenceDialog> createState() => _FastTravelSequenceDialogState();
}

class _FastTravelSequenceDialogState extends State<FastTravelSequenceDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  Timer? _milestoneTimer;
  int _milestoneIndex = 0;
  bool _hasArrived = false;

  final List<String> _journeyMilestones = [
    'Gathering trail rations & saddling mounts...',
    'Marching along charted provincial highways...',
    'Passing through misty valleys & ancient ruins...',
    'Navigating frontier watchtowers & wayposts...',
    'Approaching realm gates and defensive ramparts...',
    'Arrival safe and sound! Welcome to the realm.',
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );

    _progressController.addListener(() {
      setState(() {});
    });

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _hasArrived = true;
        });
        AudioService.instance.playSuccess();
      }
    });

    _progressController.forward();

    _milestoneTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) return;
      setState(() {
        if (_milestoneIndex < _journeyMilestones.length - 1) {
          _milestoneIndex++;
        }
      });
    });
  }

  @override
  void dispose() {
    _milestoneTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _finishTravel() {
    AudioService.instance.playSuccess();
    Navigator.of(context, rootNavigator: true).pop();
    widget.onComplete();
  }

  String _portraitForMember(PartyMemberStatus member) {
    final ch = widget.savedCharacters.where((c) => c.id == member.characterId).firstOrNull;
    if (ch != null) {
      return 'assets/avatar/portraits/${ch.race.label.toLowerCase()}.png';
    }
    final race = member.raceLabel.toLowerCase();
    if (race.contains('elf')) return 'assets/avatar/portraits/elf.png';
    if (race.contains('dwarf')) return 'assets/avatar/portraits/dwarf.png';
    if (race.contains('halfling')) return 'assets/avatar/portraits/halfling.png';
    if (race.contains('dragonborn')) return 'assets/avatar/portraits/dragonborn.png';
    if (race.contains('tiefling')) return 'assets/avatar/portraits/tiefling.png';
    if (race.contains('orc')) return 'assets/avatar/portraits/orc.png';
    if (race.contains('gnome')) return 'assets/avatar/portraits/gnome.png';
    return 'assets/avatar/portraits/human.png';
  }

  String _journeyFlavorText() {
    final from = widget.origin.name;
    final to = widget.destination.name;
    return 'The fellowship departs $from, marching in tight formation under weathered canvas banners. Across rolling hills and ancient trade routes, your company navigates the wilds towards $to, watchful for wandering beasts and roadside rumors.';
  }

  String _getPartyRole(int index, int total) {
    if (index == 0) return 'Party Leader';
    if (index == 1) return 'Vanguard Scout';
    if (index == total - 1) return 'Rear Guard';
    return 'Support & Arcana';
  }

  @override
  Widget build(BuildContext context) {
    final activePet = widget.activePet;
    final hasPet = activePet != null && activePet.id != 'none';
    final progress = _progressAnimation.value;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.8), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: ArcaneTheme.secondary.withValues(alpha: 0.35),
              blurRadius: 30,
              spreadRadius: 3,
            ),
            const BoxShadow(
              color: Colors.black,
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Fantasy Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.destination.primaryColor.withValues(alpha: 0.4),
                    const Color(0xFF131728),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.18),
                      border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFFFFD54F), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FAST TRAVEL EXPEDITION',
                          style: GoogleFonts.cinzel(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Overland March Across Charted Highways',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 10.5,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2238),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.cinzel(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFD54F),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route Display (Origin -> Destination)
                    _buildRouteCard(),

                    const SizedBox(height: 14),

                    // Atmospheric Journey Lore Quote
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131726),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_stories_rounded, size: 16, color: Color(0xFFFFD54F)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _journeyFlavorText(),
                              style: GoogleFonts.spectral(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Party Roster Section Header
                    Row(
                      children: [
                        const Icon(Icons.groups_rounded, size: 16, color: ArcaneTheme.secondary),
                        const SizedBox(width: 6),
                        Text(
                          'PARTY MEMBERS IN TRANSIT (${widget.party.length})',
                          style: GoogleFonts.cinzel(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: ArcaneTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Party Cards List
                    ...List.generate(widget.party.length, (i) {
                      final member = widget.party[i];
                      return _buildPartyMemberCard(member, i, widget.party.length);
                    }),

                    const SizedBox(height: 14),

                    // Pet Companion Section
                    Row(
                      children: [
                        const Icon(Icons.pets_rounded, size: 15, color: Color(0xFF69F0AE)),
                        const SizedBox(width: 6),
                        Text(
                          'ACTIVE PET COMPANION',
                          style: GoogleFonts.cinzel(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFF69F0AE),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (hasPet)
                      _buildPetCard(activePet)
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141724),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Text('🐾', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No active pet companion travelling. Adopt a hound, owl, or dragonling at town squares or forest glades!',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Journey Status Bar & Arrival Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0D15),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Milestone Status Text
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: _hasArrived
                            ? const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF3DD68C))
                            : const CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Color(0xFFFFD54F),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _journeyMilestones[_milestoneIndex],
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _hasArrived ? const Color(0xFF3DD68C) : const Color(0xFFFFD54F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                        _hasArrived ? const Color(0xFF3DD68C) : const Color(0xFFFFD54F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Fast Travel Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasArrived
                            ? widget.destination.primaryColor
                            : const Color(0xFF22283A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _hasArrived
                                ? widget.destination.accentColor
                                : ArcaneTheme.secondary.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        elevation: _hasArrived ? 6 : 2,
                      ),
                      onPressed: _finishTravel,
                      icon: Icon(
                        _hasArrived ? Icons.explore_rounded : Icons.fast_forward_rounded,
                        size: 18,
                        color: const Color(0xFFFFD54F),
                      ),
                      label: Text(
                        _hasArrived
                            ? 'ENTER ${widget.destination.name.toUpperCase()}'
                            : 'ARRIVE IMMEDIATELY',
                        style: GoogleFonts.cinzel(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141829),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Origin Realm Pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEPARTURE',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(widget.origin.icon, size: 14, color: widget.origin.accentColor),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        widget.origin.name,
                        style: GoogleFonts.cinzel(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.origin.threatLevel.toUpperCase(),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),

          // Glowing Arrow / Highway Waypoint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                const Icon(Icons.arrow_forward_rounded, color: Color(0xFFFFD54F), size: 22),
                Text(
                  'HIGHWAY',
                  style: GoogleFonts.cinzel(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFD54F),
                  ),
                ),
              ],
            ),
          ),

          // Destination Realm Pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'DESTINATION',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: const Color(0xFFFFD54F),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        widget.destination.name,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.cinzel(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(widget.destination.icon, size: 14, color: widget.destination.accentColor),
                  ],
                ),
                Text(
                  widget.destination.threatLevel.toUpperCase(),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: widget.destination.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyMemberCard(PartyMemberStatus member, int index, int total) {
    final portrait = _portraitForMember(member);
    final hpFactor = (member.hp / max(1, member.maxHp)).clamp(0.0, 1.0);
    final role = _getPartyRole(index, total);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF141829),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: index == 0
              ? const Color(0xFFFFD54F).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Member Portrait
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: index == 0 ? const Color(0xFFFFD54F) : ArcaneTheme.secondary,
                width: 1.5,
              ),
              image: DecorationImage(
                image: AssetImage(portrait),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name and Race/Class
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        style: GoogleFonts.cinzel(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: index == 0
                            ? const Color(0xFFFFD54F).withValues(alpha: 0.18)
                            : const Color(0xFF1F2942),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: index == 0 ? const Color(0xFFFFD54F) : Colors.white24,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          color: index == 0 ? const Color(0xFFFFD54F) : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${member.raceLabel} • ${member.classLabel} • AC ${member.armorClass}',
                  style: GoogleFonts.ibmPlexSans(fontSize: 10, color: Colors.white60),
                ),
                const SizedBox(height: 4),
                // Health Bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: hpFactor,
                          minHeight: 4,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation(
                            hpFactor > 0.4 ? const Color(0xFF3DD68C) : Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${member.hp}/${member.maxHp} HP',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: hpFactor > 0.4 ? const Color(0xFF3DD68C) : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(PetCompanion pet) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pet.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pet.color.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pet Animated Emoji Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pet.color.withValues(alpha: 0.2),
              border: Border.all(color: pet.color, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(pet.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),

          // Pet Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pet.name,
                      style: GoogleFonts.cinzel(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: pet.color.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: pet.color, width: 0.8),
                      ),
                      child: Text(
                        pet.perkTitle.toUpperCase(),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          color: pet.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  pet.perkDescription,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 10,
                    color: Colors.white70,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '🐾 Marching proudly beside the party, watching for hidden trail dangers.',
                  style: GoogleFonts.spectral(
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF69F0AE),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
