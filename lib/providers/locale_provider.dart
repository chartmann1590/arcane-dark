import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/translation_service.dart';

final translationServiceProvider = ChangeNotifierProvider<TranslationService>((ref) {
  return TranslationService.instance;
});

final currentLanguageProvider = Provider<AppLanguage>((ref) {
  final service = ref.watch(translationServiceProvider);
  return service.currentLanguage;
});
