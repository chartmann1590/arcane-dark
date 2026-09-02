import 'package:flutter_tts/flutter_tts.dart';

/// A voice available from the device's own installed TTS engine (Android
/// ships Google's speech-services voices by default — free, on-device or
/// network-synthesized by Google with no API key ever touched by this app,
/// and no per-request cost). We never bundle or download voices ourselves;
/// we just list and use whatever the OS already offers.
class TtsVoice {
  final String name;
  final String locale;
  const TtsVoice({required this.name, required this.locale});

  Map<String, String> toMap() => {'name': name, 'locale': locale};

  @override
  bool operator ==(Object other) => other is TtsVoice && other.name == name && other.locale == locale;
  @override
  int get hashCode => Object.hash(name, locale);
}

/// Thin wrapper around flutter_tts (Android's native TextToSpeech engine).
/// Every voice it can list is already installed and free — this class never
/// talks to any paid or key-gated API.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  List<TtsVoice>? _cachedVoices;
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _initialized = true;
  }

  /// All voices the device's TTS engine reports, deduped and sorted with
  /// English voices first (most likely to sound natural for this app's
  /// English narration) but every installed locale is included.
  Future<List<TtsVoice>> listVoices() async {
    if (_cachedVoices != null) return _cachedVoices!;
    await _ensureInit();
    final raw = await _tts.getVoices;
    final seen = <String>{};
    final voices = <TtsVoice>[];
    if (raw is List) {
      for (final v in raw) {
        if (v is Map) {
          final name = v['name']?.toString();
          final locale = v['locale']?.toString();
          if (name == null || locale == null) continue;
          final key = '$name|$locale';
          if (!seen.add(key)) continue;
          // Network-only voices can hang for seconds with no feedback and
          // fail outright offline — stick to what's guaranteed to work now.
          final features = v['features'];
          if (features is List && features.contains('networkTimeout')) continue;
          voices.add(TtsVoice(name: name, locale: locale));
        }
      }
    }
    voices.sort((a, b) {
      final aEn = a.locale.startsWith('en') ? 0 : 1;
      final bEn = b.locale.startsWith('en') ? 0 : 1;
      if (aEn != bEn) return aEn - bEn;
      return a.name.compareTo(b.name);
    });
    _cachedVoices = voices;
    return voices;
  }

  Future<void> _applyVoice(TtsVoice? voice) async {
    await _ensureInit();
    if (voice != null) {
      await _tts.setVoice(voice.toMap());
    }
  }

  Future<void> speak(String text, {TtsVoice? voice}) async {
    if (text.trim().isEmpty) return;
    await stop();
    await _applyVoice(voice);
    await _tts.speak(text);
  }

  Future<void> preview(TtsVoice voice, {String sample = "Hello, I'm ready for adventure."}) => speak(sample, voice: voice);

  Future<void> stop() => _tts.stop();
}
