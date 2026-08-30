import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';

class AppSettings {
  final bool hasDownloadedModel;
  final bool onboardingSkipped;
  final String modelTier; // E2B / E4B
  final bool haptics;
  final bool musicEnabled;
  final bool sfxEnabled;
  final double textScale;
  const AppSettings({
    this.hasDownloadedModel = false,
    this.onboardingSkipped = false,
    this.modelTier = 'E2B',
    this.haptics = true,
    this.musicEnabled = true,
    this.sfxEnabled = true,
    this.textScale = 1.0,
  });
  AppSettings copyWith({
    bool? hasDownloadedModel,
    bool? onboardingSkipped,
    String? modelTier,
    bool? haptics,
    bool? musicEnabled,
    bool? sfxEnabled,
    double? textScale,
  }) =>
      AppSettings(
        hasDownloadedModel: hasDownloadedModel ?? this.hasDownloadedModel,
        onboardingSkipped: onboardingSkipped ?? this.onboardingSkipped,
        modelTier: modelTier ?? this.modelTier,
        haptics: haptics ?? this.haptics,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        sfxEnabled: sfxEnabled ?? this.sfxEnabled,
        textScale: textScale ?? this.textScale,
      );
}

/// Static, synchronous-at-startup check (reads SharedPreferences directly, not via
/// the Riverpod provider, since it must run before ProviderScope exists in main()).
Future<bool> shouldShowOnboardingOnLaunch() async {
  final p = await SharedPreferences.getInstance();
  final downloaded = p.getBool('hasDownloadedModel') ?? false;
  final skipped = p.getBool('onboardingSkipped') ?? false;
  return !downloaded && !skipped;
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = AppSettings(
      hasDownloadedModel: p.getBool('hasDownloadedModel') ?? false,
      onboardingSkipped: p.getBool('onboardingSkipped') ?? false,
      modelTier: p.getString('modelTier') ?? 'E2B',
      haptics: p.getBool('haptics') ?? true,
      musicEnabled: p.getBool('musicEnabled') ?? true,
      sfxEnabled: p.getBool('sfxEnabled') ?? true,
      textScale: p.getDouble('textScale') ?? 1.0,
    );
    await AudioService.instance.init(musicEnabled: state.musicEnabled, sfxEnabled: state.sfxEnabled);
  }

  Future<void> setModelDownloaded(bool v) async {
    state = state.copyWith(hasDownloadedModel: v);
    (await SharedPreferences.getInstance()).setBool('hasDownloadedModel', v);
  }

  Future<void> setOnboardingSkipped(bool v) async {
    state = state.copyWith(onboardingSkipped: v);
    (await SharedPreferences.getInstance()).setBool('onboardingSkipped', v);
  }

  Future<void> setModelTier(String tier) async {
    state = state.copyWith(modelTier: tier);
    (await SharedPreferences.getInstance()).setString('modelTier', tier);
  }

  Future<void> setMusicEnabled(bool v) async {
    state = state.copyWith(musicEnabled: v);
    (await SharedPreferences.getInstance()).setBool('musicEnabled', v);
    await AudioService.instance.setMusicEnabled(v);
  }

  Future<void> setSfxEnabled(bool v) async {
    state = state.copyWith(sfxEnabled: v);
    (await SharedPreferences.getInstance()).setBool('sfxEnabled', v);
    AudioService.instance.setSfxEnabled(v);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());
