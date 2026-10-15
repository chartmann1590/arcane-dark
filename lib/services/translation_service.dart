import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String code; // BCP-47 code (e.g. 'en', 'es', 'pt')
  final String name; // English name
  final String nativeName; // Native name
  final String flag; // Emoji flag
  final TranslateLanguage mlKitLanguage;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.mlKitLanguage,
  });
}

class TranslationService extends ChangeNotifier {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const String prefKey = 'app_selected_language';

  static const List<AppLanguage> supportedLanguages = [
    AppLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
      mlKitLanguage: TranslateLanguage.english,
    ),
    AppLanguage(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
      mlKitLanguage: TranslateLanguage.spanish,
    ),
    AppLanguage(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      flag: '🇧🇷',
      mlKitLanguage: TranslateLanguage.portuguese,
    ),
    AppLanguage(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
      mlKitLanguage: TranslateLanguage.french,
    ),
    AppLanguage(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
      mlKitLanguage: TranslateLanguage.german,
    ),
    AppLanguage(
      code: 'it',
      name: 'Italian',
      nativeName: 'Italiano',
      flag: '🇮🇹',
      mlKitLanguage: TranslateLanguage.italian,
    ),
    AppLanguage(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      flag: '🇯🇵',
      mlKitLanguage: TranslateLanguage.japanese,
    ),
    AppLanguage(
      code: 'ko',
      name: 'Korean',
      nativeName: '한국어',
      flag: '🇰🇷',
      mlKitLanguage: TranslateLanguage.korean,
    ),
    AppLanguage(
      code: 'zh',
      name: 'Chinese (Simplified)',
      nativeName: '中文',
      flag: '🇨🇳',
      mlKitLanguage: TranslateLanguage.chinese,
    ),
    AppLanguage(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
      flag: '🇷🇺',
      mlKitLanguage: TranslateLanguage.russian,
    ),
    AppLanguage(
      code: 'pl',
      name: 'Polish',
      nativeName: 'Polski',
      flag: '🇵🇱',
      mlKitLanguage: TranslateLanguage.polish,
    ),
    AppLanguage(
      code: 'nl',
      name: 'Dutch',
      nativeName: 'Nederlands',
      flag: '🇳🇱',
      mlKitLanguage: TranslateLanguage.dutch,
    ),
    AppLanguage(
      code: 'tr',
      name: 'Turkish',
      nativeName: 'Türkçe',
      flag: '🇹🇷',
      mlKitLanguage: TranslateLanguage.turkish,
    ),
    AppLanguage(
      code: 'uk',
      name: 'Ukrainian',
      nativeName: 'Українська',
      flag: '🇺🇦',
      mlKitLanguage: TranslateLanguage.ukrainian,
    ),
    AppLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      flag: '🇮🇳',
      mlKitLanguage: TranslateLanguage.hindi,
    ),
    AppLanguage(
      code: 'vi',
      name: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      flag: '🇻🇳',
      mlKitLanguage: TranslateLanguage.vietnamese,
    ),
    AppLanguage(
      code: 'id',
      name: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
      flag: '🇮🇩',
      mlKitLanguage: TranslateLanguage.indonesian,
    ),
  ];

  final OnDeviceTranslatorModelManager _modelManager = OnDeviceTranslatorModelManager();
  OnDeviceTranslator? _currentTranslator;

  AppLanguage _currentLanguage = supportedLanguages.first; // English default
  AppLanguage get currentLanguage => _currentLanguage;
  String get currentLanguageCode => _currentLanguage.code;
  bool get isEnglish => _currentLanguage.code == 'en';

  bool _isDownloadingModel = false;
  bool get isDownloadingModel => _isDownloadingModel;

  String? _downloadError;
  String? get downloadError => _downloadError;

  // Language code -> { english_text: translated_text }
  final Map<String, Map<String, String>> _cache = {};

  // Set of in-flight translation keys to prevent duplicate concurrent calls
  final Set<String> _pendingTranslations = {};

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initializes the service from SharedPreferences on app startup.
  Future<void> init([String? initialLanguageCode]) async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = initialLanguageCode ?? prefs.getString(prefKey) ?? 'en';
      final lang = getLanguageByCode(savedCode);
      await _applyLanguage(lang, persist: false, wifiOnly: false);
      _initialized = true;
    } catch (e) {
      debugPrint('[TranslationService] init error: $e');
      _currentLanguage = supportedLanguages.first;
      _initialized = true;
    }
  }

  AppLanguage getLanguageByCode(String code) {
    return supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => supportedLanguages.first,
    );
  }

  /// Checks if the ML Kit model for a given language is already downloaded.
  Future<bool> isModelDownloaded(String code) async {
    if (code == 'en') return true;
    try {
      return await _modelManager.isModelDownloaded(code);
    } catch (e) {
      debugPrint('[TranslationService] isModelDownloaded error for $code: $e');
      return false;
    }
  }

  /// Sets the active language, downloading the ML Kit model if needed.
  /// Notifies all listeners immediately once the translator is ready.
  Future<bool> setLanguage(String code, {bool wifiOnly = false}) async {
    final lang = getLanguageByCode(code);
    if (lang.code == _currentLanguage.code && _currentTranslator != null) {
      return true;
    }
    return await _applyLanguage(lang, persist: true, wifiOnly: wifiOnly);
  }

  Future<bool> _applyLanguage(AppLanguage lang, {bool persist = true, bool wifiOnly = false}) async {
    _downloadError = null;

    if (lang.code == 'en') {
      _currentTranslator?.close();
      _currentTranslator = null;
      _currentLanguage = lang;
      _isDownloadingModel = false;
      if (persist) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefKey, 'en');
      }
      notifyListeners();
      return true;
    }

    _isDownloadingModel = true;
    notifyListeners();

    try {
      // 1. Check if model is downloaded; if not, download it
      final downloaded = await _modelManager.isModelDownloaded(lang.code);
      if (!downloaded) {
        debugPrint('[TranslationService] Downloading ML Kit model for ${lang.name} (${lang.code})...');
        final success = await _modelManager.downloadModel(lang.code, isWifiRequired: wifiOnly);
        debugPrint('[TranslationService] ML Kit model download result for ${lang.code}: $success');
      }

      // 2. Setup translator
      _currentTranslator?.close();
      _currentTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: lang.mlKitLanguage,
      );

      _currentLanguage = lang;
      _isDownloadingModel = false;

      if (persist) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefKey, lang.code);
      }

      debugPrint('[TranslationService] Successfully activated language: ${lang.name} (${lang.code})');
      notifyListeners();

      // Warm cache with common UI strings in background
      unawaited(preloadStrings(commonUiStrings));

      return true;
    } catch (e) {
      debugPrint('[TranslationService] Failed to set language ${lang.code}: $e');
      _downloadError = e.toString();
      _isDownloadingModel = false;
      notifyListeners();
      return false;
    }
  }

  static const List<String> commonUiStrings = [
    'Home',
    'Heroes',
    'Play',
    'Party',
    'Settings',
    'Attack',
    'Search',
    'Cast Spell',
    'Tactics',
    'Short Rest',
    'Campfire',
    'Talk',
    'Roll Die',
    'Skip',
    'Resume',
    'Continue',
    'Music',
    'Sound Effects',
    'Voice Narration',
    'Send Diagnostics',
    'Report AI Content / Issue',
    'Change Language',
    'Sign In',
    'Sign Out',
    'Current Campaign',
  ];

  /// Synchronously returns translated text if cached or English.
  /// If not yet cached, returns [text] and schedules an async translation that
  /// will populate the cache and notify listeners when ready.
  String translateSync(String text) {
    if (isEnglish || text.trim().isEmpty) return text;

    final langCache = _cache[_currentLanguage.code];
    if (langCache != null && langCache.containsKey(text)) {
      return langCache[text]!;
    }

    // Schedule background translation if not already pending
    final key = '${_currentLanguage.code}:$text';
    if (!_pendingTranslations.contains(key) && _currentTranslator != null) {
      _pendingTranslations.add(key);
      _translateAndCache(text, _currentLanguage.code).then((_) {
        _pendingTranslations.remove(key);
      });
    }

    return text;
  }

  /// Translates [text] asynchronously from English to the current language.
  /// Returns the cached translation if available.
  Future<String> translate(String text) async {
    if (isEnglish || text.trim().isEmpty) return text;

    final langCache = _cache[_currentLanguage.code];
    if (langCache != null && langCache.containsKey(text)) {
      return langCache[text]!;
    }

    return await _translateAndCache(text, _currentLanguage.code);
  }

  Future<String> _translateAndCache(String text, String langCode) async {
    if (_currentTranslator == null || langCode != _currentLanguage.code) {
      return text;
    }

    try {
      final translated = await _currentTranslator!.translateText(text);
      final langCache = _cache.putIfAbsent(langCode, () => <String, String>{});
      langCache[text] = translated;
      notifyListeners();
      return translated;
    } catch (e) {
      debugPrint('[TranslationService] Error translating text for $langCode: $e');
      return text;
    }
  }

  /// Preloads a batch of common strings so they render immediately without any delay.
  Future<void> preloadStrings(List<String> strings) async {
    if (isEnglish || _currentTranslator == null) return;
    for (final s in strings) {
      if (s.trim().isNotEmpty && !(_cache[_currentLanguage.code]?.containsKey(s) ?? false)) {
        await _translateAndCache(s, _currentLanguage.code);
      }
    }
  }

  @override
  void dispose() {
    _currentTranslator?.close();
    super.dispose();
  }
}
