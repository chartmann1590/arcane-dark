import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';
import 'crash_reporting.dart';

/// Call once at app startup, before runApp. Requests GDPR/UK consent info
/// first (required by AdMob policy for EEA/UK users) and only initializes
/// the ads SDK — meaning no ad request is even attempted — once consent has
/// been gathered or determined not to apply. Never blocks app startup for
/// more than [_consentTimeout]: if the consent form fails to load (offline
/// first launch, etc.), ads simply stay off for this session rather than
/// hanging the splash screen.
const _consentTimeout = Duration(seconds: 8);

Future<void> initializeAds() async {
  final params = ConsentRequestParameters();
  final completer = Completer<void>();

  ConsentInformation.instance.requestConsentInfoUpdate(
    params,
    () async {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        await _loadAndShowConsentFormIfRequired();
      }
      if (!completer.isCompleted) completer.complete();
    },
    (FormError error) {
      CrashReporting.log('Consent info update failed: ${error.message}');
      if (!completer.isCompleted) completer.complete();
    },
  );

  await completer.future.timeout(_consentTimeout, onTimeout: () {});

  final canRequestAds = await ConsentInformation.instance.canRequestAds();
  if (canRequestAds) {
    await MobileAds.instance.initialize();
  } else {
    CrashReporting.log('Ads not initialized this session: consent not yet obtainable (offline?).');
  }
}

Future<void> _loadAndShowConsentFormIfRequired() async {
  final completer = Completer<void>();
  ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
    if (error != null) CrashReporting.log('Consent form error: ${error.message}');
    if (!completer.isCompleted) completer.complete();
  });
  await completer.future.timeout(_consentTimeout, onTimeout: () {});
}

/// Exposed for a "Privacy Choices" / "Manage Ad Consent" entry in Settings,
/// per AdMob's requirement that users be able to revisit their choice.
Future<void> showPrivacyOptionsFormIfAvailable() async {
  final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
  if (status != PrivacyOptionsRequirementStatus.required) return;
  final completer = Completer<void>();
  ConsentForm.showPrivacyOptionsForm((FormError? error) {
    if (!completer.isCompleted) completer.complete();
  });
  await completer.future;
}

/// Reusable adaptive banner. Fails silently (collapses to zero height) if an
/// ad can't be filled, so the layout never breaks on ad-blocked or offline
/// devices — the game must stay playable even with zero ad fill.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          CrashReporting.log('Banner ad failed to load: $error');
        },
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// Loads one interstitial ahead of time and shows it on demand at natural
/// checkpoints (finishing character creation, starting a new campaign) —
/// never mid-narration or mid-combat. Always reloads the next one after a
/// show/dismiss/failure so there's rarely a wait.
class InterstitialAdManager {
  InterstitialAdManager._();
  static final InterstitialAdManager instance = InterstitialAdManager._();

  InterstitialAd? _ad;
  bool _loading = false;

  void preload() {
    if (_ad != null || _loading) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          CrashReporting.log('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  /// Shows the preloaded interstitial if one is ready; otherwise does
  /// nothing (never blocks the user waiting for an ad to load).
  void showIfReady() {
    final ad = _ad;
    if (ad == null) {
      preload();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        preload();
      },
    );
    ad.show();
  }
}
