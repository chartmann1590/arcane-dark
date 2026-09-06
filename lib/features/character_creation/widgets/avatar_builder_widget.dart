import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../domain/character.dart';
import '../../../services/audio_service.dart';

class AvatarBuilderWidget extends StatelessWidget {
  final Race race;
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;

  const AvatarBuilderWidget({
    super.key,
    required this.race,
    required this.config,
    required this.onChanged,
  });

  static const _auras = <(String, String, IconData, Color, Color)>[
    ('arcane', 'Arcane Storm', Icons.bolt_rounded, Color(0xFF8B5CF6), Color(0xFF06B6D4)),
    ('flame', 'Infernal Ember', Icons.local_fire_department_rounded, Color(0xFFEF4444), Color(0xFFF97316)),
    ('celestial', 'Celestial Dawn', Icons.wb_sunny_rounded, Color(0xFFF59E0B), Color(0xFFFEF08A)),
    ('void', 'Void Shroud', Icons.nightlight_round, Color(0xFF6B21A8), Color(0xFF3B0764)),
    ('verdant', 'Verdant Life', Icons.spa_rounded, Color(0xFF10B981), Color(0xFF34D399)),
    ('steel', 'Runic Steel', Icons.shield_rounded, Color(0xFF94A3B8), Color(0xFFE2E8F0)),
  ];

  static const _titles = [
    'The Undaunted',
    'Shadowbane',
    'Stormbringer',
    'The Spellweaver',
    'Ironclad',
    'The Merciful',
    'Dragon-Eyed',
    'The Relentless',
    'Dawnblade',
    'The Silent Warden',
  ];

  static const _weapons = <(String, IconData)>[
    ('Runed Greatsword', Icons.hardware_rounded),
    ('Arcane Crystal Staff', Icons.auto_awesome_rounded),
    ('Dual Daggers', Icons.flash_on_rounded),
    ('Longbow of Whispers', Icons.navigation_rounded),
    ('Thunder Hammer', Icons.gavel_rounded),
    ('Aegis & Blade', Icons.shield_rounded),
  ];

  static const _battleCries = [
    'For glory and the dawn!',
    'By blood and steel!',
    'Magic obeys my command!',
    'Shadows claim the wicked!',
    'None shall pass while I stand!',
  ];

  (Color, Color) get _activeAuraColors {
    final aura = _auras.firstWhere((a) => a.$1 == config.aura, orElse: () => _auras.first);
    return (aura.$4, aura.$5);
  }

  void _randomizeTitle() {
    AudioService.instance.playDiceRoll();
    final next = _titles[Random().nextInt(_titles.length)];
    onChanged(config.copyWith(title: next));
  }

  @override
  Widget build(BuildContext context) {
    final (c1, c2) = _activeAuraColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Character Portrait Card with glowing aura & badges
        Container(
          height: 290,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF161522),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c1.withValues(alpha: 0.8), width: 2),
            boxShadow: [
              BoxShadow(color: c1.withValues(alpha: 0.45), blurRadius: 28, spreadRadius: -2),
              BoxShadow(color: c2.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: -4),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Portrait art
              Image.asset('assets/avatar/portraits/${race.name}.png', fit: BoxFit.cover),
              // Dynamic Aura gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      c1.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),

              // Top Badges (Title & Aura)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c1.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.military_tech_rounded, size: 14, color: c1),
                          const SizedBox(width: 5),
                          Text(
                            config.title.toUpperCase(),
                            style: GoogleFonts.cinzel(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: c1.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flare_rounded, size: 12, color: c1),
                          const SizedBox(width: 4),
                          Text(
                            config.aura.toUpperCase(),
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Badges (Weapon & Battle Cry)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            race.label.toUpperCase(),
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c2.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shield_moon_rounded, size: 13, color: c2),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    config.weapon,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (config.battleCry.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '"${config.battleCry}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spectral(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.amber.shade200,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Heroic Title Selection & Roll
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'HEROIC EPITHET',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: ArcaneTheme.textMuted,
              ),
            ),
            InkWell(
              onTap: _randomizeTitle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.casino_rounded, size: 14, color: ArcaneTheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'Roll Title',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ArcaneTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _titles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final t = _titles[i];
              final isSel = config.title == t;
              return ChoiceChip(
                label: Text(t, style: GoogleFonts.ibmPlexSans(fontSize: 11.5, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                selected: isSel,
                selectedColor: ArcaneTheme.primary.withValues(alpha: 0.35),
                backgroundColor: ArcaneTheme.surfaceElevated,
                side: BorderSide(color: isSel ? ArcaneTheme.primary : Colors.white12),
                onSelected: (val) {
                  if (val) {
                    AudioService.instance.playTap();
                    onChanged(config.copyWith(title: t));
                  }
                },
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Elemental Aura
        Text(
          'ELEMENTAL AURA',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: ArcaneTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _auras.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final (id, name, icon, col1, _) = _auras[i];
              final isSel = config.aura == id;
              return InkWell(
                onTap: () {
                  AudioService.instance.playTap();
                  onChanged(config.copyWith(aura: id));
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? col1.withValues(alpha: 0.25) : ArcaneTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSel ? col1 : Colors.white12, width: isSel ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 15, color: col1),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Signature Weapon
        Text(
          'SIGNATURE WEAPON',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: ArcaneTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _weapons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final (wName, icon) = _weapons[i];
              final isSel = config.weapon == wName;
              return InkWell(
                onTap: () {
                  AudioService.instance.playTap();
                  onChanged(config.copyWith(weapon: wName));
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? ArcaneTheme.secondary.withValues(alpha: 0.2) : ArcaneTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSel ? ArcaneTheme.secondary : Colors.white12, width: isSel ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 14, color: isSel ? ArcaneTheme.secondary : Colors.white54),
                      const SizedBox(width: 6),
                      Text(
                        wName,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Battle Cry Presets
        Text(
          'RALLYING BATTLE CRY',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: ArcaneTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _battleCries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final cry = _battleCries[i];
              final isSel = config.battleCry == cry;
              return InkWell(
                onTap: () {
                  AudioService.instance.playTap();
                  onChanged(config.copyWith(battleCry: cry));
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? Colors.amber.withValues(alpha: 0.2) : ArcaneTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSel ? Colors.amber : Colors.white12),
                  ),
                  child: Text(
                    '"$cry"',
                    style: GoogleFonts.spectral(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: isSel ? Colors.amber.shade200 : Colors.white60,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Frame / Accent Color
        Text(
          'ACCENT & HIGHLIGHT COLOR',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: ArcaneTheme.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in ['#8B5CF6', '#C9A227', '#B0263A', '#3DD68C', '#4EA1F5', '#EC4899', '#F97316', '#F5F3FF'])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: InkWell(
                  onTap: () {
                    AudioService.instance.playTap();
                    onChanged(config.copyWith(eyeColor: c));
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(int.parse(c.replaceAll('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: Border.all(color: config.eyeColor == c ? Colors.white : Colors.transparent, width: 2.2),
                      boxShadow: config.eyeColor == c ? [BoxShadow(color: ArcaneTheme.primary.withValues(alpha: 0.5), blurRadius: 10)] : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
