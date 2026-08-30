import 'dart:io' show Platform;

/// AdMob configuration — banner + interstitial.
///
/// *** REPLACE BEFORE STORE SUBMISSION ***
/// The IDs below are Google's official public TEST ad unit IDs
/// (https://developers.google.com/admob/flutter/test-ads). They always serve
/// safe test creatives and are meant to ship in development builds — using
/// real ad unit IDs before your AdMob account/app is approved risks a policy
/// strike. Swap every value in this file for your real AdMob App ID and ad
/// unit IDs once you have them, and set [useTestAds] to false.
class AdConfig {
  /// Flip to false once the real IDs below are filled in.
  static const bool useTestAds = true;

  /// Also set the matching value in:
  ///   android/app/src/main/AndroidManifest.xml -> com.google.android.gms.ads.APPLICATION_ID
  ///   ios/Runner/Info.plist -> GADApplicationIdentifier
  static const String _androidAppIdTest = 'ca-app-pub-3940256099942544~3347511713';
  static const String _iosAppIdTest = 'ca-app-pub-3940256099942544~1458002511';

  // TODO: paste your real IDs here once AdMob issues them.
  static const String _androidAppIdReal = 'ca-app-pub-REPLACE_ME~REPLACE_ME';
  static const String _iosAppIdReal = 'ca-app-pub-REPLACE_ME~REPLACE_ME';

  static const String _androidBannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTest = 'ca-app-pub-3940256099942544/2934735716';
  static const String _androidBannerReal = 'ca-app-pub-REPLACE_ME/REPLACE_ME';
  static const String _iosBannerReal = 'ca-app-pub-REPLACE_ME/REPLACE_ME';

  static const String _androidInterstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitialTest = 'ca-app-pub-3940256099942544/4411468910';
  static const String _androidInterstitialReal = 'ca-app-pub-REPLACE_ME/REPLACE_ME';
  static const String _iosInterstitialReal = 'ca-app-pub-REPLACE_ME/REPLACE_ME';

  static String get appId {
    if (useTestAds) return Platform.isIOS ? _iosAppIdTest : _androidAppIdTest;
    return Platform.isIOS ? _iosAppIdReal : _androidAppIdReal;
  }

  static String get bannerUnitId {
    if (useTestAds) return Platform.isIOS ? _iosBannerTest : _androidBannerTest;
    return Platform.isIOS ? _iosBannerReal : _androidBannerReal;
  }

  static String get interstitialUnitId {
    if (useTestAds) return Platform.isIOS ? _iosInterstitialTest : _androidInterstitialTest;
    return Platform.isIOS ? _iosInterstitialReal : _androidInterstitialReal;
  }
}
