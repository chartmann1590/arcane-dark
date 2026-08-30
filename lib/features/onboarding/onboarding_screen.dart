import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../providers/settings_provider.dart';
import '../../services/audio_service.dart';
import '../../services/model_download_manager.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  double progress = 0;
  bool downloading = false;
  bool done = false;
  String? error;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playMusic(MusicTrack.tavern);
  }

  Future<void> _skip() async {
    await ref.read(settingsProvider.notifier).setOnboardingSkipped(true);
    if (mounted) context.go('/home');
  }

  Future<void> _startDownload() async {
    setState(() {
      downloading = true;
      error = null;
    });
    final mgr = ModelDownloadManager();
    try {
      await for (final p in mgr.downloadWithProgress()) {
        if (!mounted) return;
        setState(() => progress = p);
      }
      await ref.read(settingsProvider.notifier).setModelDownloaded(true);
      if (!mounted) return;
      setState(() {
        downloading = false;
        done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        downloading = false;
        progress = 0;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ArcaneTheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.auto_awesome_rounded, color: ArcaneTheme.primary)),
              const SizedBox(width: 10),
              Text('ARCANE DARK', style: GoogleFonts.playfairDisplay(color: ArcaneTheme.secondary, letterSpacing: 2, fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              TextButton(onPressed: _skip, child: Text('Skip', style: GoogleFonts.manrope(color: ArcaneTheme.textMuted))),
            ]),
            const SizedBox(height: 24),
            Text('Your AI Dungeon Master\nawaits.', style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
            const SizedBox(height: 12),
            Text('This app runs a powerful story engine directly on your device — no cloud, no subscription, works in airplane mode after a one-time download.', style: GoogleFonts.manrope(fontSize: 14, color: ArcaneTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.border)),
              child: Column(children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.storage_rounded, color: ArcaneTheme.secondary, size: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Gemma 4 E2B • ~2.6GB • One-time download', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white))),
                ]),
                const SizedBox(height: 10),
                Text('Stored in private app storage. You\'ll be asked for Wi-Fi confirmation before downloading. LiteRT-LM runs it locally — no story text ever leaves your device in solo mode.', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary, height: 1.4)),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: downloading || done ? progress : 0, minHeight: 6, backgroundColor: ArcaneTheme.surfaceElevated, valueColor: AlwaysStoppedAnimation(done ? const Color(0xFF3DD68C) : ArcaneTheme.primary))),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(downloading ? '${(progress * 100).toInt()}% • Downloading...' : done ? 'Download complete ✓' : 'Ready to download', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted)),
                  Text(done ? 'Ready to play' : 'Wi-Fi recommended', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted)),
                ]),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: ArcaneTheme.tertiary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: ArcaneTheme.tertiary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(error!, style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.tertiary))),
                    ]),
                  ),
                ],
              ]),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: downloading
                    ? null
                    : done
                        ? () => context.go('/home')
                        : _startDownload,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(downloading ? 'Downloading…' : done ? 'Enter the Tavern →' : 'Download & Continue', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ),
            ),
            const SizedBox(height: 10),
            if (!done && !downloading)
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _skip, child: Text('Continue without download (demo narration)', style: GoogleFonts.manrope(fontSize: 12)))),
            const SizedBox(height: 8),
            Text('You can always download later from Settings → AI Configuration.', textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
          ]),
        ),
      ),
    );
  }
}
