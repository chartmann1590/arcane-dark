import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../domain/character.dart';

class AvatarBuilderWidget extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const AvatarBuilderWidget({super.key, required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Portrait preview — stylized silhouette stack mimicking Stitch's layered appearance screen
      Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ArcaneTheme.border),
          image: const DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=600'),
            fit: BoxFit.cover,
            opacity: 0.85,
          ),
        ),
        child: Stack(children: [
          Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.55)]))),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(int.parse(config.eyeColor.replaceAll('#', '0xFF'))), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(config.face.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.manrope(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ArcaneTheme.primary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_fix_high_rounded, size: 16, color: Colors.white),
              ),
            ]),
          ),
          // Layer indicators (body/face/hair/outfit/accessory) as subtle overlays
          Positioned(
            top: 10,
            right: 10,
            child: Column(children: [
              _LayerDot(label: 'Body', active: true),
              _LayerDot(label: 'Face', active: config.face != 'face_1'),
              _LayerDot(label: 'Hair', active: config.hair != 'hair_1'),
              _LayerDot(label: 'Outfit', active: config.outfit != 'outfit_1'),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      // Controls
      _Carousel(
        label: 'Facial Structure',
        options: const ['face_1', 'face_2', 'face_3', 'face_4'],
        selected: config.face,
        onSelect: (v) => onChanged(config.copyWith(face: v)),
      ),
      const SizedBox(height: 12),
      _Carousel(
        label: 'Hair',
        options: const ['hair_1', 'hair_2', 'hair_3', 'hair_4', 'hair_5'],
        selected: config.hair,
        onSelect: (v) => onChanged(config.copyWith(hair: v)),
      ),
      const SizedBox(height: 12),
      _Carousel(
        label: 'Outfit',
        options: const ['outfit_1', 'outfit_2', 'outfit_3', 'outfit_4'],
        selected: config.outfit,
        onSelect: (v) => onChanged(config.copyWith(outfit: v)),
      ),
      const SizedBox(height: 16),
      Text('EYE COLOR', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: ArcaneTheme.textMuted)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final c in ['#8B5CF6', '#C9A227', '#B0263A', '#3DD68C', '#F5F3FF', '#1A162B'])
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
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () {
          final opts = ['face_1', 'face_2', 'face_3', 'face_4'];
          final hairs = ['hair_1', 'hair_2', 'hair_3', 'hair_4', 'hair_5'];
          final outfits = ['outfit_1', 'outfit_2', 'outfit_3', 'outfit_4'];
          opts.shuffle();
          hairs.shuffle();
          outfits.shuffle();
          onChanged(config.copyWith(face: opts.first, hair: hairs.first, outfit: outfits.first));
        },
        icon: const Icon(Icons.shuffle_rounded, size: 16),
        label: Text('Randomize', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class _Carousel extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  const _Carousel({required this.label, required this.options, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: ArcaneTheme.textMuted)),
      const SizedBox(height: 8),
      SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (c, i) {
            final opt = options[i];
            final isSel = opt == selected;
            return InkWell(
              onTap: () => onSelect(opt),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 64,
                decoration: BoxDecoration(
                  color: ArcaneTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSel ? ArcaneTheme.primary : ArcaneTheme.border, width: isSel ? 1.5 : 1),
                  boxShadow: isSel ? [BoxShadow(color: ArcaneTheme.primary.withOpacity(0.2), blurRadius: 8)] : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.person_rounded, color: isSel ? ArcaneTheme.primary : ArcaneTheme.textMuted),
                  const SizedBox(height: 4),
                  Text(opt.replaceAll('_', ' '), style: GoogleFonts.manrope(fontSize: 10, color: isSel ? ArcaneTheme.primary : ArcaneTheme.textSecondary, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _LayerDot extends StatelessWidget {
  final String label;
  final bool active;
  const _LayerDot({required this.label, required this.active});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: active ? ArcaneTheme.primary.withOpacity(0.18) : Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? ArcaneTheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.1))),
        child: Text(label, style: GoogleFonts.manrope(fontSize: 10, color: active ? ArcaneTheme.primary : Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600)),
      ),
    );
  }
}
