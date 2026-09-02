import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../services/tts_service.dart';

/// A bottom sheet listing every voice the device's own TTS engine offers —
/// all free, all on-device or Google-synthesized with no API key — with a
/// tap-to-preview button on each row. Returns the chosen voice, or null if
/// the user backed out without picking one.
Future<TtsVoice?> showVoicePicker(BuildContext context, {TtsVoice? current, String sampleText = "Hello, I'm ready for adventure."}) {
  return showModalBottomSheet<TtsVoice>(
    context: context,
    backgroundColor: ArcaneTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (c) => _VoicePickerSheet(current: current, sampleText: sampleText),
  );
}

class _VoicePickerSheet extends StatefulWidget {
  final TtsVoice? current;
  final String sampleText;
  const _VoicePickerSheet({this.current, required this.sampleText});

  @override
  State<_VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends State<_VoicePickerSheet> {
  List<TtsVoice>? _voices;
  String? _error;
  TtsVoice? _playing;
  late TtsVoice? _selected = widget.current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final voices = await TtsService.instance.listVoices();
      if (!mounted) return;
      setState(() => _voices = voices);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not read voices from this device: $e');
    }
  }

  Future<void> _preview(TtsVoice v) async {
    setState(() => _playing = v);
    await TtsService.instance.preview(v, sample: widget.sampleText);
    if (mounted) setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Choose a Voice', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Free, on-device voices — tap ▶ to preview, tap a row to select.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
            const SizedBox(height: 12),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSans(color: ArcaneTheme.textSecondary)))
                  : _voices == null
                      ? const Center(child: CircularProgressIndicator())
                      : _voices!.isEmpty
                          ? Center(child: Text('No voices found on this device.', style: GoogleFonts.ibmPlexSans(color: ArcaneTheme.textSecondary)))
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: _voices!.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (c, i) {
                                final v = _voices![i];
                                final isSelected = _selected == v;
                                final isPlaying = _playing == v;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() => _selected = v),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? ArcaneTheme.primary.withOpacity(0.14) : ArcaneTheme.surfaceCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSelected ? ArcaneTheme.primary : ArcaneTheme.border),
                                    ),
                                    child: Row(children: [
                                      Icon(isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: isSelected ? ArcaneTheme.primary : ArcaneTheme.textMuted, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(v.name, style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          Text(v.locale, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textMuted)),
                                        ]),
                                      ),
                                      IconButton(
                                        onPressed: () => _preview(v),
                                        icon: isPlaying
                                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                            : const Icon(Icons.play_circle_fill_rounded),
                                        color: ArcaneTheme.secondary,
                                      ),
                                    ]),
                                  ),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    TtsService.instance.stop();
                    Navigator.pop(context);
                  },
                  child: Text('Cancel', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () {
                          TtsService.instance.stop();
                          Navigator.pop(context, _selected);
                        },
                  child: Text('Use This Voice', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }
}
