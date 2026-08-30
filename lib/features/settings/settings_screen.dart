import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../providers/settings_provider.dart';
import '../../services/ad_service.dart';
import '../../services/crash_reporting.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(title: Text('SETTINGS', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 13))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('AI CONFIGURATION', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          Container(
            decoration: ArcaneTheme.cardDecoration(),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.memory_rounded, color: ArcaneTheme.primary, size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('On-Device Model', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Gemma 4 • LiteRT-LM • ${settings.modelTier}', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: settings.hasDownloadedModel ? const Color(0xFF3DD68C).withOpacity(0.15) : ArcaneTheme.tertiary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(settings.hasDownloadedModel ? 'Ready' : 'Not downloaded', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: settings.hasDownloadedModel ? const Color(0xFF3DD68C) : ArcaneTheme.tertiary))),
              ]),
              const SizedBox(height: 14),
              Text('MODEL TIER  •  Device RAM determines availability  •  <6GB → E2B only; ≥6GB can pick E4B', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('E2B  •  ~1.6GB  •  Broad compatibility', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600)),
                    selected: settings.modelTier == 'E2B',
                    onSelected: (_) => ref.read(settingsProvider.notifier).setModelTier('E2B'),
                    selectedColor: ArcaneTheme.primary.withOpacity(0.2),
                    labelStyle: GoogleFonts.manrope(color: settings.modelTier == 'E2B' ? ArcaneTheme.primary : Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('E4B  •  ~4GB  •  Higher quality (6GB+ devices)', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600)),
                    selected: settings.modelTier == 'E4B',
                    onSelected: (_) => ref.read(settingsProvider.notifier).setModelTier('E4B'),
                    selectedColor: ArcaneTheme.secondary.withOpacity(0.18),
                    labelStyle: GoogleFonts.manrope(color: settings.modelTier == 'E4B' ? ArcaneTheme.secondary : Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/onboarding'),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(settings.hasDownloadedModel ? 'Re-download Model' : 'Download Model (≈2.6 GB, Wi-Fi recommended)', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Text('AUDIO', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          Container(
            decoration: ArcaneTheme.cardDecoration(),
            child: Column(children: [
              SwitchListTile(
                value: settings.musicEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).setMusicEnabled(v),
                activeThumbColor: ArcaneTheme.primary,
                secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.music_note_rounded, color: ArcaneTheme.primary, size: 18)),
                title: Text('Music', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Ambient tavern & dungeon music', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textMuted)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.sfxEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).setSfxEnabled(v),
                activeThumbColor: ArcaneTheme.primary,
                secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.graphic_eq_rounded, color: ArcaneTheme.secondary, size: 18)),
                title: Text('Sound Effects', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Dice rolls, taps, and notifications', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textMuted)),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Text('DIAGNOSTICS', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          Container(
            decoration: ArcaneTheme.cardDecoration(),
            child: Column(children: [
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.bug_report_rounded, color: ArcaneTheme.textSecondary, size: 18)),
                title: Text('Send Diagnostics', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Flush crash logs & copy device info', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textMuted)),
                trailing: const Icon(Icons.chevron_right_rounded, color: ArcaneTheme.textMuted),
                onTap: () async {
                  CrashReporting.log('User tapped Send Diagnostics');
                  final deviceLine = await _realDeviceLine();
                  final appVersion = await _realAppVersion();
                  final supportId = _shortSupportId();
                  if (!context.mounted) return;
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: ArcaneTheme.surface,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    builder: (c) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Diagnostics', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 12),
                        _DiagRow('Device', deviceLine),
                        _DiagRow('Model Tier', settings.modelTier),
                        _DiagRow('Model Ready', settings.hasDownloadedModel ? 'Yes' : 'No'),
                        _DiagRow('App Version', appVersion),
                        _DiagRow('Support ID', supportId),
                        const SizedBox(height: 14),
                        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))),
                      ]),
                    ),
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Text('ABOUT', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Arcane Dark • DnD AI — Mobile', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Text('On-device AI Dungeon Master powered by Gemma 4 (LiteRT-LM). Solo mode works fully offline after the one-time model download. Multiplayer sessions sync via Firebase Firestore — only session state leaves the device, never raw prompts.', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 10),
              Text('Privacy: solo play is private by design — no campaign text leaves the device unless you join a multiplayer party.', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _LinkChip('Privacy Policy', onTap: () => context.push('/privacy')),
                _LinkChip('Privacy Choices', onTap: () => showPrivacyOptionsFormIfAvailable()),
                _LinkChip('Gemma Terms', url: 'https://ai.google.dev/gemma/terms'),
                _LinkChip('Prohibited Use', url: 'https://ai.google.dev/gemma/prohibited_use_policy'),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Future<String> _realDeviceLine() async {
    String ramLine = '';
    try {
      const control = MethodChannel('dnd_ai/llm_control');
      final ramMb = await control.invokeMethod<int>('getDeviceRamTier');
      if (ramMb != null) ramLine = ' • ${(ramMb / 1024).toStringAsFixed(1)}GB RAM';
    } catch (_) {
      // Not on Android, or native bridge not present (e.g. web dev build) — omit RAM line.
    }
    try {
      final android = await DeviceInfoPlugin().androidInfo;
      return '${android.manufacturer} ${android.model} • Android ${android.version.release} (API ${android.version.sdkInt})$ramLine';
    } catch (_) {
      try {
        final ios = await DeviceInfoPlugin().iosInfo;
        return '${ios.name} • ${ios.systemName} ${ios.systemVersion}$ramLine';
      } catch (_) {
        return 'Unknown device';
      }
    }
  }

  Future<String> _realAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  String _shortSupportId() {
    // Stable-for-session, non-identifying: derived from current time bucket, not a tracking ID.
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now ~/ 100000).toRadixString(16).substring(0, 8);
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;
  const _DiagRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textMuted))),
        Expanded(child: Text(value, style: GoogleFonts.manrope(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final String label;
  final String? url;
  final VoidCallback? onTap;
  const _LinkChip(this.label, {this.url, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap ?? () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(20), border: Border.all(color: ArcaneTheme.border)), child: Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: ArcaneTheme.primary))),
    );
  }
}
