import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../domain/character.dart';

class AvatarBuilderWidget extends StatelessWidget {
  final Race race;
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const AvatarBuilderWidget({super.key, required this.race, required this.config, required this.onChanged});

  Color get _accent => Color(int.parse(config.eyeColor.replaceAll('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Real portrait art (see plan/07-ui-design-stitch.md — generated via Stitch,
      // one illustration per race since true layered sprite compositing needs
      // transparent per-layer art Stitch's screen generator can't produce).
      Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 24, spreadRadius: -4)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/avatar/portraits/${race.name}.png', fit: BoxFit.cover),
          Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.55)]))),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: Text(race.label.toUpperCase(), style: GoogleFonts.manrope(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_fix_high_rounded, size: 16, color: Colors.white),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Text('ACCENT COLOR', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: ArcaneTheme.textMuted)),
      const SizedBox(height: 4),
      Text('Tints your portrait frame and in-game highlight color.', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final c in ['#8B5CF6', '#C9A227', '#B0263A', '#3DD68C', '#4EA1F5', '#F5F3FF'])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              onTap: () => onChanged(config.copyWith(eyeColor: c)),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Color(int.parse(c.replaceAll('#', '0xFF'))), shape: BoxShape.circle, border: Border.all(color: config.eyeColor == c ? Colors.white : Colors.transparent, width: 2), boxShadow: config.eyeColor == c ? [BoxShadow(color: ArcaneTheme.primary.withOpacity(0.4), blurRadius: 8)] : null),
              ),
            ),
          ),
      ]),
    ]);
  }
}
