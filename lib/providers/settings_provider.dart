import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool hasDownloadedModel;
  final bool onboardingSkipped;
  final String modelTier; // E2B / E4B
  final bool haptics;
  final double textScale;
  const AppSettings({this.hasDownloadedModel = false, this.onboardingSkipped = false, this.modelTier = 'E2B', this.haptics = true, this.textScale = 1.0});
  AppSettings copyWith({bool? hasDownloadedModel, bool? onboardingSkipped, String? modelTier, bool? haptics, double? textScale}) =>
      AppSettings(
        hasDownloadedModel: hasDownloadedModel ?? this.hasDownloadedModel,
        onboardingSkipped: onboardingSkipped ?? this.onboardingSkipped,
        modelTier: modelTier ?? this.modelTier,
        haptics: haptics ?? this.haptics,
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
      textScale: p.getDouble('textScale') ?? 1.0,
    );
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
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());
