import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../providers/character_provider.dart';
import 'steps/race_step.dart';
import 'steps/class_step.dart';
import 'steps/background_step.dart';
import 'steps/abilities_step.dart';
import 'steps/appearance_step.dart';
import 'steps/review_step.dart';

class CharacterCreationFlow extends ConsumerStatefulWidget {
  const CharacterCreationFlow({super.key});
  @override
  ConsumerState<CharacterCreationFlow> createState() => _CharacterCreationFlowState();
}

class _CharacterCreationFlowState extends ConsumerState<CharacterCreationFlow> {
  final _pageController = PageController();
  int _index = 0;
  final _nameController = TextEditingController();

  final titles = ['Choose Your Race', 'Choose Your Class', 'Choose Your Background', 'Ability Scores', 'Appearance', 'Review'];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < 5) {
      setState(() => _index++);
      _pageController.animateToPage(_index, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
      _pageController.animateToPage(_index, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(characterDraftProvider);
    final canProceed = switch (_index) {
      0 => true,
      1 => true,
      2 => true,
      3 => draft.abilities.totalCost() <= 27,
      4 => draft.name.isNotEmpty || _nameController.text.isNotEmpty,
      _ => true,
    };

    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        title: Text(titles[_index].toUpperCase(), style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: ArcaneTheme.secondary)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('STEP ${_index + 1} OF 6', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  if (_index >= 4)
                    Text(draft.name.isEmpty ? 'Final Details' : draft.name, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textSecondary)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: (_index + 1) / 6, minHeight: 4, backgroundColor: ArcaneTheme.surfaceElevated, valueColor: const AlwaysStoppedAnimation(ArcaneTheme.primary)),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                const RaceStep(),
                const ClassStep(),
                const BackgroundStep(),
                const AbilitiesStep(),
                AppearanceStep(nameController: _nameController),
                const ReviewStep(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: ArcaneTheme.border)), color: ArcaneTheme.background),
            child: Row(children: [
              if (_index > 0)
                Expanded(child: OutlinedButton(onPressed: _back, child: const Text('Back')))
              else
                const Expanded(child: SizedBox()),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: canProceed
                      ? () {
                          if (_index < 5) {
                            _next();
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: ArcaneTheme.primary),
                  child: Text(_index == 5 ? 'Finish' : 'Continue'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
