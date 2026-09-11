import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/ad_service.dart';
import '../../services/auth_service.dart';
import '../../services/crash_reporting.dart';
import '../../services/translation_service.dart';
import '../../widgets/ai_report_dialog.dart';
import '../../widgets/translated_text.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final hasRealAccount = ref.watch(hasRealAccountProvider);
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(title: TrText('SETTINGS', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 13))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TrText('LANGUAGE & TRANSLATION', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: TranslationService.instance,
            builder: (context, _) {
              final service = TranslationService.instance;
              final currentLang = service.currentLanguage;
              final isDownloading = service.isDownloadingModel;
              return Container(
                decoration: ArcaneTheme.cardDecoration(),
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.translate_rounded, color: ArcaneTheme.secondary, size: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TrText('App & Story Language', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('${currentLang.flag} ${currentLang.nativeName} (${currentLang.name})', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDownloading
                            ? ArcaneTheme.primary.withValues(alpha: 0.15)
                            : currentLang.code == 'en'
                                ? Colors.blue.withValues(alpha: 0.15)
                                : const Color(0xFF3DD68C).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isDownloading
                            ? 'Downloading...'
                            : currentLang.code == 'en'
                                ? 'Native'
                                : 'Active ✓',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDownloading
                              ? ArcaneTheme.primary
                              : currentLang.code == 'en'
                                  ? Colors.blue
                                  : const Color(0xFF3DD68C),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TrText(
                    'On-device ML Kit translates all AI Dungeon Master narratives, chat messages, choices, and menus offline. Changing language downloads the translation pack and updates the entire app immediately.',
                    style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isDownloading ? null : () => showLanguageSelectionSheet(context),
                      icon: const Icon(Icons.language_rounded, size: 16),
                      label: TrText(
                        'Change Language',
                        style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 18),
          TrText('ACCOUNT', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          Container(
            decoration: ArcaneTheme.cardDecoration(),
            padding: const EdgeInsets.all(14),
            child: hasRealAccount
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF3DD68C).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.verified_user_rounded, color: Color(0xFF3DD68C), size: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TrText('Signed in', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(authUser?.email ?? authUser?.displayName ?? 'Characters sync to the cloud', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
                      ])),
                      TextButton(onPressed: () => AuthService.instance.signOut(), child: TrText('Sign Out', style: GoogleFonts.ibmPlexSans(color: ArcaneTheme.tertiary, fontWeight: FontWeight.w700, fontSize: 12))),
                    ]),
                    const Divider(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(
                        child: TrText('Delete account & cloud data', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted)),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmDeleteAccount(context),
                        icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Color(0xFFEF4444)),
                        label: TrText('Delete Account', style: GoogleFonts.ibmPlexSans(color: const Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ])
                : Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person_outline_rounded, color: ArcaneTheme.primary, size: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TrText('Playing as a guest', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, color: Colors.white)),
                      TrText('Sign in to back up characters and play multiplayer', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
                    ])),
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
                      },
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
                      child: TrText('Sign In', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ]),
          ),
          const SizedBox(height: 18),
          TrText('AI CONFIGURATION', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          Container(
            decoration: ArcaneTheme.cardDecoration(),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.memory_rounded, color: ArcaneTheme.primary, size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TrText('On-Device Model', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Gemma 4 • LiteRT-LM • ${settings.modelTier}', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: settings.hasDownloadedModel ? const Color(0xFF3DD68C).withValues(alpha: 0.15) : ArcaneTheme.tertiary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Text(settings.hasDownloadedModel ? 'Ready' : 'Not downloaded', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: settings.hasDownloadedModel ? const Color(0xFF3DD68C) : ArcaneTheme.tertiary))),
              ]),
              const SizedBox(height: 14),
              TrText('MODEL TIER  •  Device RAM determines availability  •  <6GB → E2B only; ≥6GB can pick E4B', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textMuted)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('E2B  •  ~1.6GB  •  Broad compatibility', style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600)),
                    selected: settings.modelTier == 'E2B',
                    onSelected: (_) => ref.read(settingsProvider.notifier).setModelTier('E2B'),
                    selectedColor: ArcaneTheme.primary.withValues(alpha: 0.2),
                    labelStyle: GoogleFonts.ibmPlexSans(color: settings.modelTier == 'E2B' ? ArcaneTheme.primary : Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('E4B  •  ~4GB  •  Higher quality (6GB+ devices)', style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600)),
                    selected: settings.modelTier == 'E4B',
                    onSelected: (_) => ref.read(settingsProvider.notifier).setModelTier('E4B'),
                    selectedColor: ArcaneTheme.secondary.withValues(alpha: 0.18),
                    labelStyle: GoogleFonts.ibmPlexSans(color: settings.modelTier == 'E4B' ? ArcaneTheme.secondary : Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/onboarding'),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: TrText(settings.hasDownloadedModel ? 'Re-download Model' : 'Download Model (≈2.6 GB, Wi-Fi recommended)', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          TrText('AUDIO', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          Container(
            decoration: ArcaneTheme.cardDecoration(),
            child: Column(children: [
              SwitchListTile(
                value: settings.musicEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).setMusicEnabled(v),
                activeThumbColor: ArcaneTheme.primary,
                secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.music_note_rounded, color: ArcaneTheme.primary, size: 18)),
                title: TrText('Music', style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: TrText('Ambient tavern & dungeon music', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.sfxEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).setSfxEnabled(v),
                activeThumbColor: ArcaneTheme.primary,
                secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.graphic_eq_rounded, color: ArcaneTheme.secondary, size: 18)),
                title: TrText('Sound Effects', style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: TrText('Dice rolls, taps, and notifications', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.voiceNarrationEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).setVoiceNarrationEnabled(v),
                activeThumbColor: ArcaneTheme.primary,
                secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.tertiary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.record_voice_over_rounded, color: ArcaneTheme.tertiary, size: 18)),
                title: TrText('Voice Narration', style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: TrText('Speaks DM narration aloud using on-device voices', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted)),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          TrText('DIAGNOSTICS', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          Container(
            decoration: ArcaneTheme.cardDecoration(),
            child: Column(children: [
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.bug_report_rounded, color: ArcaneTheme.textSecondary, size: 18)),
                title: TrText('Send Diagnostics', style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: TrText('Flush crash logs & copy device info', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted)),
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
                        Text('Diagnostics', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
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
          TrText('AI SAFETY & COMPLIANCE', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: ArcaneTheme.cardDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: ArcaneTheme.tertiary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.shield_outlined, color: ArcaneTheme.tertiary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TrText('Content Safety & Reporting', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, color: Colors.white)),
                  TrText('Flag inappropriate, harmful, or rule-violating AI output', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
                ])),
              ]),
              const SizedBox(height: 10),
              TrText(
                'Arcane Dark adheres strictly to Google Play Generative AI policies. You can report any AI narrative in-game via the flag icon or directly submit a safety report below.',
                style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted, height: 1.45),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => showAiReportDialog(context),
                  icon: const Icon(Icons.report_problem_outlined, size: 16),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ArcaneTheme.surfaceElevated,
                    foregroundColor: ArcaneTheme.tertiary,
                    side: BorderSide(color: ArcaneTheme.tertiary.withValues(alpha: 0.5)),
                  ),
                  label: TrText('Report AI Content / Issue', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          TrText('ABOUT', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ArcaneTheme.textMuted)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Arcane Dark • DnD AI — Mobile', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              TrText('On-device AI Dungeon Master powered by Gemma 4 (LiteRT-LM). Solo mode works fully offline after the one-time model download. Multiplayer sessions sync via Firebase Firestore — only session state leaves the device, never raw prompts.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 10),
              TrText('Privacy: solo play is private by design — no campaign text leaves the device unless you join a multiplayer party.', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _LinkChip('Privacy Policy', onTap: () => context.push('/privacy')),
                _LinkChip('Delete Account / Data', url: 'https://chartmann1590.github.io/arcane-dark/delete-account.html'),
                _LinkChip('Report AI Issue', onTap: () => showAiReportDialog(context)),
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

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArcaneTheme.surface,
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
          const SizedBox(width: 10),
          Expanded(child: Text('Delete Account?', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18))),
        ]),
        content: Text(
          'This will permanently delete your account, authentication credentials, and all cloud-synced hero rosters from our servers. Solo campaigns saved locally on this device will not be affected.\n\nThis action cannot be undone.',
          style: GoogleFonts.ibmPlexSans(fontSize: 13, color: ArcaneTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.ibmPlexSans(color: ArcaneTheme.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB0263A), foregroundColor: Colors.white),
            child: Text('Permanently Delete', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await AuthService.instance.deleteAccount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF3DD68C),
              content: Text('Your account and associated cloud data have been deleted.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFB0263A),
              content: Text(AuthService.instance.friendlyError(e)),
            ),
          );
        }
      }
    }
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
        SizedBox(width: 110, child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted))),
        Expanded(child: Text(value, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600))),
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
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(20), border: Border.all(color: ArcaneTheme.border)), child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600, color: ArcaneTheme.primary))),
    );
  }
}
