import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../domain/campaign_seed.dart';
import '../domain/character.dart';
import '../domain/companion_templates.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';

/// Shows the party assembly sheet before starting an offline campaign.
/// Enforces having at least one AI companion so that single-player mode
/// operates as a true offline party campaign.
void showPartyAssembler({
  required BuildContext context,
  required WidgetRef ref,
  required CampaignSeed seed,
  required List<Character> playerCharacters,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: ArcaneTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PartyAssemblerDialog(
      seed: seed,
      playerCharacters: playerCharacters,
    ),
  );
}

class _PartyAssemblerDialog extends ConsumerStatefulWidget {
  final CampaignSeed seed;
  final List<Character> playerCharacters;

  const _PartyAssemblerDialog({
    required this.seed,
    required this.playerCharacters,
  });

  @override
  ConsumerState<_PartyAssemblerDialog> createState() => _PartyAssemblerDialogState();
}

class _PartyAssemblerDialogState extends ConsumerState<_PartyAssemblerDialog> {
  late String _selectedLeaderId;
  final Set<String> _selectedCompanionNames = {};

  @override
  void initState() {
    super.initState();
    _selectedLeaderId = widget.playerCharacters.first.id;
    if (companionTemplates.isNotEmpty) {
      _selectedCompanionNames.add(companionTemplates.first.name);
    }
  }

  void _toggleCompanion(String name) {
    setState(() {
      if (_selectedCompanionNames.contains(name)) {
        _selectedCompanionNames.remove(name);
      } else {
        if (_selectedCompanionNames.length < 3) {
          _selectedCompanionNames.add(name);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Party limit reached (Leader + 3 Companions)', style: GoogleFonts.ibmPlexSans()),
              backgroundColor: ArcaneTheme.tertiary,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  Future<void> _embark() async {
    final leader = widget.playerCharacters.firstWhere(
      (c) => c.id == _selectedLeaderId,
      orElse: () => widget.playerCharacters.first,
    );

    final savedList = ref.read(savedCharactersProvider);
    final party = <Character>[leader];

    for (final name in _selectedCompanionNames) {
      final template = companionTemplates.firstWhere((t) => t.name == name);
      Character? existing = savedList.where((c) => c.name == name).firstOrNull;
      if (existing == null) {
        existing = template.toCharacter();
        await ref.read(savedCharactersProvider.notifier).add(existing);
      }
      party.add(existing);
    }

    ref.read(campaignProvider.notifier).startNew(widget.seed, party);
    AudioService.instance.playSuccess();

    if (mounted) {
      Navigator.of(context).pop();
      context.go('/play');
      InterstitialAdManager.instance.showIfReady();
    }
  }

  @override
  Widget build(BuildContext context) {
    final leader = widget.playerCharacters.firstWhere(
      (c) => c.id == _selectedLeaderId,
      orElse: () => widget.playerCharacters.first,
    );
    final hasMinCompanions = _selectedCompanionNames.isNotEmpty;
    final totalPartySize = 1 + _selectedCompanionNames.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ArcaneTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ArcaneTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_moon_rounded, color: ArcaneTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ASSEMBLE YOUR PARTY',
                            style: GoogleFonts.cinzel(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.seed.title,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ArcaneTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ArcaneTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ArcaneTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: ArcaneTheme.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'An offline campaign requires at least one AI companion to watch your back. Assemble up to 3 companions for a full party.',
                          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'PARTY LEADER (YOU)',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: ArcaneTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.playerCharacters.length == 1)
                  _HeroCard(character: leader, isSelected: true, onTap: null)
                else
                  ...widget.playerCharacters.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _HeroCard(
                          character: c,
                          isSelected: c.id == _selectedLeaderId,
                          onTap: () => setState(() => _selectedLeaderId = c.id),
                        ),
                      )),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI COMPANIONS (1 TO 3 REQUIRED)',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: ArcaneTheme.textMuted,
                      ),
                    ),
                    Text(
                      '${_selectedCompanionNames.length}/3 selected',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasMinCompanions ? ArcaneTheme.secondary : ArcaneTheme.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...companionTemplates.map((template) {
                  final isSelected = _selectedCompanionNames.contains(template.name);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _toggleCompanion(template.name),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? ArcaneTheme.primary.withOpacity(0.12) : ArcaneTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? ArcaneTheme.primary : ArcaneTheme.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: ArcaneTheme.primary.withOpacity(0.2),
                              backgroundImage: AssetImage('assets/avatar/portraits/${template.race.name}.png'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        template.name,
                                        style: GoogleFonts.cinzel(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ArcaneTheme.secondary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${template.race.label} • ${template.charClass.label}',
                                          style: GoogleFonts.ibmPlexSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: ArcaneTheme.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    template.tagline,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 11,
                                      color: ArcaneTheme.textSecondary,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? ArcaneTheme.primary : ArcaneTheme.textMuted,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: ArcaneTheme.border)),
              color: ArcaneTheme.background,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasMinCompanions ? _embark : null,
                icon: const Icon(Icons.explore_rounded, size: 20),
                label: Text(
                  hasMinCompanions
                      ? 'Descend into Darkness ($totalPartySize Heroes)'
                      : 'Select at least 1 Companion to Embark',
                  style: GoogleFonts.ibmPlexSans(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: ArcaneTheme.primary,
                  disabledBackgroundColor: ArcaneTheme.surfaceElevated,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Character character;
  final bool isSelected;
  final VoidCallback? onTap;

  const _HeroCard({
    required this.character,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? ArcaneTheme.secondary.withOpacity(0.1) : ArcaneTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ArcaneTheme.secondary : ArcaneTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: ArcaneTheme.secondary.withOpacity(0.2),
              backgroundImage: AssetImage('assets/avatar/portraits/${character.race.name}.png'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: GoogleFonts.cinzel(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${character.race.label} • ${character.charClass.label} • HP ${character.hp}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: ArcaneTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ArcaneTheme.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Leader',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ArcaneTheme.secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
