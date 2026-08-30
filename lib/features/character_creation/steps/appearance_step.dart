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
          race: draft.race,
          config: draft.avatar,
          onChanged: (c) => ref.read(characterDraftProvider.notifier).setAvatar(c),
        ),
      ],
    );
  }
}
