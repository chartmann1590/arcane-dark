import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service managing system-level casting integrations:
/// - Google Cast / Chromecast native route picker
/// - Miracast / Wireless Display (Wi-Fi Direct / Samsung Smart View / LG Screen Share)
/// - One-tap Google Chrome Cast Forwarding
class SystemCastService {
  SystemCastService._();
  static final SystemCastService instance = SystemCastService._();

  static const MethodChannel _channel = MethodChannel('dnd_ai/system_cast');

  /// Whether running on Android where native Cast & Miracast intents are supported
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Launches the native Android Cast / Screen Cast picker
  /// (Settings.ACTION_CAST_SETTINGS).
  /// This scans for Chromecast, Google TV, Nest Hub, and Android TV targets.
  Future<bool> launchChromecastPicker() async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openCastSettings');
      return res ?? true;
    } catch (e) {
      debugPrint('[SystemCastService] Failed to open Cast settings: $e');
      return false;
    }
  }

  /// Launches the native Android Wireless Display / Miracast picker
  /// (android.settings.WIFI_DISPLAY_SETTINGS with fallback to ACTION_CAST_SETTINGS).
  /// Compatible with Samsung Smart View, LG Screen Share, Roku, Fire TV, and Windows Wireless Display.
  Future<bool> launchMiracastPicker() async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openMiracastSettings');
      return res ?? true;
    } catch (e) {
      debugPrint('[SystemCastService] Failed to open Miracast settings: $e');
      return false;
    }
  }

  /// Opens the live local TV Cast stream in Google Chrome so the user can
  /// tap Chrome's native Cast button to stream directly to any Chromecast.
  Future<bool> launchInChrome(String url) async {
    if (isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('openChrome', {'url': url});
        if (res == true) return true;
      } catch (e) {
        debugPrint('[SystemCastService] Chrome intent failed: $e, falling back to url_launcher');
      }
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
