import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../domain/character.dart';
import '../../domain/persona.dart';
import '../../providers/campaign_provider.dart';
import '../../providers/character_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/audio_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/fx.dart';
import '../../widgets/voice_picker_sheet.dart';

class CharacterDetailScreen extends ConsumerStatefulWidget {
  final String characterId;
  const CharacterDetailScreen({super.key, required this.characterId});
  @override
  ConsumerState<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends ConsumerState<CharacterDetailScreen> {
  final _inputCtrl = TextEditingController();
  final List<Map<String, String>> _chat = [];
  bool _sending = false;
  String _streaming = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(campaignProvider.notifier).loadPersisted());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _send(Character character, String text, {required bool onCampaign, required String campaignContext}) async {
    if (text.trim().isEmpty || _sending) return;
    AudioService.instance.playSend();
    setState(() {
      _chat.add({'role': 'player', 'text': text});
      _sending = true;
      _streaming = '';
    });
    _inputCtrl.clear();
    final persona = character.personaDescription;
    final prompt = StringBuffer()
      ..writeln('You are roleplaying as ${character.name}, a level ${character.level} ${character.race.label} ${character.charClass.label} with the background "${character.background.label}".')
      ..writeln('Your persona: $persona')
      ..writeln(onCampaign ? 'Current adventure status: $campaignContext' : 'You are not currently on an active adventure.')
      ..writeln('Speak only in first person as ${character.name}. Never break character, never mention being an AI. Keep replies to 2-4 sentences.')
      ..writeln('\nSomeone says to you: "$text"')
      ..writeln('\n${character.name} replies:');
    try {
      final model = ref.read(modelServiceProvider);
      await for (final chunk in model.generate(prompt.toString())) {
        if (!mounted) return;
        setState(() => _streaming += chunk);
      }
      final reply = _streaming.trim();
      setState(() {
        _chat.add({'role': 'char', 'text': reply});
        _sending = false;
        _streaming = '';
      });
      if (ref.read(settingsProvider).voiceNarrationEnabled && reply.isNotEmpty) {
        final voiceName = character.voiceName;
        TtsService.instance.speak(reply, voice: (voiceName != null && voiceName.isNotEmpty) ? TtsVoice(name: voiceName, locale: character.voiceLocale ?? 'en-US') : null);
      }
    } catch (e) {
      AudioService.instance.playError();
      if (!mounted) return;
      setState(() {
        _chat.add({'role': 'char', 'text': '(${character.name} seems lost in thought — the AI model may not be downloaded yet. Check Settings.)'});
        _sending = false;
        _streaming = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chars = ref.watch(savedCharactersProvider);
    final character = chars.where((c) => c.id == widget.characterId).firstOrNull;
    if (character == null) {
      return Scaffold(backgroundColor: ArcaneTheme.background, body: Center(child: Text('Hero not found', style: GoogleFonts.ibmPlexSans(color: ArcaneTheme.textSecondary))));
    }

    final campaign = ref.watch(campaignProvider);
    final onCampaign = campaign != null && campaign.party.any((m) => m.characterId == character.id);
    String campaignContext = '';
    if (onCampaign) {
      final activeQuest = campaign.questLog.where((q) => q.status == 'active').firstOrNull;
      campaignContext = 'You are on the campaign "${campaign.seed.title}" (${campaign.seed.tone}). Current scene: ${campaign.currentSceneDescription}'
          '${activeQuest != null ? ' Current quest: ${activeQuest.title} (${activeQuest.stage}).' : ''}';
    }

    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(title: Text(character.name.toUpperCase(), style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1))),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [
              PopIn(
                child: Container(
                  decoration: ArcaneTheme.ornateDecoration(),
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    CircleAvatar(radius: 44, backgroundColor: ArcaneTheme.primary.withOpacity(0.15), backgroundImage: AssetImage('assets/avatar/portraits/${character.race.name}.png')),
                    const SizedBox(height: 10),
                    Text(character.name, style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (character.avatar.title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(character.avatar.title.toUpperCase(), style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.amber.shade200, letterSpacing: 1.1)),
                    ],
                    const SizedBox(height: 4),
                    Text('${character.race.label} • ${character.charClass.label} • ${character.background.label}', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _Pill('HP ${character.hp}', ArcaneTheme.tertiary),
                      const SizedBox(width: 8),
                      _Pill('AC ${character.armorClass}', ArcaneTheme.secondary),
                      const SizedBox(width: 8),
                      _Pill('Lv ${character.level}', ArcaneTheme.primary),
                    ]),
                    if (character.avatar.weapon.isNotEmpty || character.avatar.aura.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.shield_moon_rounded, size: 12, color: ArcaneTheme.secondary),
                            const SizedBox(width: 4),
                            Text(character.avatar.weapon, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: Colors.white70)),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: ArcaneTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: ArcaneTheme.primary.withValues(alpha: 0.4))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.flare_rounded, size: 12, color: ArcaneTheme.primary),
                            const SizedBox(width: 4),
                            Text('${character.avatar.aura.toUpperCase()} AURA', style: GoogleFonts.ibmPlexSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: ArcaneTheme.primary)),
                          ]),
                        ),
                      ]),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: ArcaneTheme.cardDecoration(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ABILITY SCORES', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: ArcaneTheme.textMuted)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _Score('STR', character.abilities.str, character.abilities.strMod),
                    _Score('DEX', character.abilities.dex, character.abilities.dexMod),
                    _Score('CON', character.abilities.con, character.abilities.conMod),
                    _Score('INT', character.abilities.int_, character.abilities.intMod),
                    _Score('WIS', character.abilities.wis, character.abilities.wisMod),
                    _Score('CHA', character.abilities.cha, character.abilities.chaMod),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: ArcaneTheme.cardDecoration(),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.tertiary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.record_voice_over_rounded, color: ArcaneTheme.tertiary, size: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('VOICE', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: ArcaneTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(character.voiceName == null || character.voiceName!.isEmpty ? 'System default' : character.voiceName!, style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final current = (character.voiceName != null && character.voiceName!.isNotEmpty) ? TtsVoice(name: character.voiceName!, locale: character.voiceLocale ?? 'en-US') : null;
                      final picked = await showVoicePicker(context, current: current, sampleText: 'Hello, I am ${character.name}, ready for adventure.');
                      if (picked != null) await ref.read(savedCharactersProvider.notifier).updateVoice(character.id, picked.name, picked.locale);
                    },
                    child: Text('Change', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: onCampaign ? ArcaneTheme.primary.withOpacity(0.08) : ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: onCampaign ? ArcaneTheme.primary.withOpacity(0.3) : ArcaneTheme.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(onCampaign ? Icons.auto_stories_rounded : Icons.bedtime_rounded, size: 16, color: onCampaign ? ArcaneTheme.primary : ArcaneTheme.textMuted),
                    const SizedBox(width: 8),
                    Text('CAMPAIGN STATUS', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: ArcaneTheme.textMuted)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    onCampaign ? '"${campaign.seed.title}" — ${campaign.currentSceneDescription}' : 'Not currently on an adventure. Start a solo campaign from Home to send ${character.name} into the world.',
                    style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary, height: 1.5),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Text('TALK TO ${character.name.toUpperCase()}', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: ArcaneTheme.textMuted)),
              const SizedBox(height: 8),
              Text('Powered by the on-device AI, speaking in ${character.name}\'s own persona and aware of their current adventure.', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              if (_chat.isEmpty && _streaming.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(12)),
                  child: Text('Say hello to ${character.name}…', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
                )
              else
                ..._chat.map((m) {
                  final isPlayer = m['role'] == 'player';
                  return FadeSlideIn(
                    child: Align(
                      alignment: isPlayer ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        decoration: BoxDecoration(color: isPlayer ? ArcaneTheme.primary : ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(12)),
                        child: Text(m['text']!, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: isPlayer ? Colors.white : ArcaneTheme.textPrimary, height: 1.4)),
                      ),
                    ),
                  );
                }),
              if (_sending)
                FadeSlideIn(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(12)),
                      child: _streaming.isEmpty
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              TypingDots(color: ArcaneTheme.textSecondary),
                              const SizedBox(width: 8),
                              Text('${character.name} is thinking…', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: ArcaneTheme.textSecondary)),
                            ])
                          : Text(_streaming, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: ArcaneTheme.textSecondary)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(color: ArcaneTheme.surface, border: Border(top: BorderSide(color: ArcaneTheme.border))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(hintText: 'Say something to ${character.name}…', filled: true, fillColor: ArcaneTheme.surfaceElevated, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                onSubmitted: (t) => _send(character, t, onCampaign: onCampaign, campaignContext: campaignContext),
              ),
            ),
            const SizedBox(width: 8),
            PressableScale(
              onTap: () => _send(character, _inputCtrl.text, onCampaign: onCampaign, campaignContext: campaignContext),
              child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: ArcaneTheme.primary, shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 18)),
            ),
          ]),
        ),
      ]),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))), child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w800, color: color)));
}

class _Score extends StatelessWidget {
  final String label;
  final int score;
  final int mod;
  const _Score(this.label, this.score, this.mod);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: ArcaneTheme.border)),
      child: Column(children: [
        Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w700, color: ArcaneTheme.textMuted, letterSpacing: 0.6)),
        Text('$score', style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(mod >= 0 ? '+$mod' : '$mod', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.secondary, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
