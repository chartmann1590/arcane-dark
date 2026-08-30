import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../providers/character_provider.dart';
import '../widgets/avatar_builder_widget.dart';

class AppearanceStep extends ConsumerWidget {
  final TextEditingController nameController;
  const AppearanceStep({super.key, required this.nameController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        TextField(
          controller: nameController,
          onChanged: (v) => ref.read(characterDraftProvider.notifier).setName(v),
          style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Hero Name',
            hintText: 'e.g. Lyra Nightwhisper',
            prefixIcon: const Icon(Icons.badge_rounded, color: ArcaneTheme.textMuted, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        AvatarBuilderWidget(
          config: draft.avatar,
          onChanged: (c) => ref.read(characterDraftProvider.notifier).setAvatar(c),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ArcaneTheme.secondary.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.secondary.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.palette_rounded, color: ArcaneTheme.secondary, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Layered avatar — swap any layer instantly. Final art from Phase 07 will drop in via manifest with zero code changes.', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textSecondary))),
          ]),
        ),
      ],
    );
  }
}
