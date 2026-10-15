import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../services/translation_service.dart';

/// Extension on [String] for instant sync lookup.
extension TranslationStringExt on String {
  String get tr => TranslationService.instance.translateSync(this);
}

/// A drop-in replacement for [Text] that automatically translates
/// into the currently selected language using on-device ML Kit translation.
class TrText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  const TrText(
    this.text, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
  });

  @override
  State<TrText> createState() => _TrTextState();
}

class _TrTextState extends State<TrText> {
  String? _translated;

  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onTranslationChanged);
    _resolve();
  }

  @override
  void didUpdateWidget(covariant TrText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _resolve();
    }
  }

  @override
  void dispose() {
    TranslationService.instance.removeListener(_onTranslationChanged);
    super.dispose();
  }

  void _onTranslationChanged() {
    if (mounted) {
      _resolve();
    }
  }

  void _resolve() {
    if (TranslationService.instance.isEnglish || widget.text.trim().isEmpty) {
      if (_translated != null) {
        setState(() => _translated = null);
      }
      return;
    }

    // Try synchronous cache first
    final syncRes = TranslationService.instance.translateSync(widget.text);
    if (syncRes != widget.text) {
      if (_translated != syncRes) {
        setState(() => _translated = syncRes);
      }
      return;
    }

    // Asynchronously resolve if not yet in cache
    TranslationService.instance.translate(widget.text).then((res) {
      if (mounted && _translated != res) {
        setState(() => _translated = res);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _translated ?? widget.text,
      style: widget.style,
      strutStyle: widget.strutStyle,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      locale: widget.locale,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
      maxLines: widget.maxLines,
      semanticsLabel: widget.semanticsLabel,
      textWidthBasis: widget.textWidthBasis,
      textHeightBehavior: widget.textHeightBehavior,
    );
  }
}

/// Modal bottom sheet allowing users to switch the app language and
/// automatically download the on-device ML Kit translation pack.
Future<void> showLanguageSelectionSheet(BuildContext context) async {
  final service = TranslationService.instance;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: ArcaneTheme.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final currentCode = service.currentLanguageCode;
          final isDownloading = service.isDownloadingModel;

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ArcaneTheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.translate_rounded, color: ArcaneTheme.secondary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SELECT LANGUAGE',
                              style: GoogleFonts.cinzel(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              'On-device ML Kit translation • 100% offline once downloaded',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 11,
                                color: ArcaneTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (isDownloading) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ArcaneTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ArcaneTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: ArcaneTheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Downloading ML Kit translation model (~30 MB)...',
                              style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (service.downloadError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ArcaneTheme.tertiary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Download note: ${service.downloadError}',
                        style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.tertiary),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  const Divider(color: ArcaneTheme.border, height: 16),

                  // Language list
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: TranslationService.supportedLanguages.length,
                      separatorBuilder: (_, __) => const Divider(color: ArcaneTheme.border, height: 1),
                      itemBuilder: (context, index) {
                        final lang = TranslationService.supportedLanguages[index];
                        final isSelected = lang.code == currentCode;

                        return FutureBuilder<bool>(
                          future: service.isModelDownloaded(lang.code),
                          builder: (context, snapshot) {
                            final isDownloaded = snapshot.data ?? (lang.code == 'en');

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
                              title: Row(
                                children: [
                                  Text(
                                    lang.nativeName,
                                    style: GoogleFonts.ibmPlexSans(
                                      color: isSelected ? ArcaneTheme.secondary : Colors.white,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    lang.name,
                                    style: GoogleFonts.ibmPlexSans(
                                      color: ArcaneTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                lang.code == 'en'
                                    ? 'Native language (no download required)'
                                    : isDownloaded
                                        ? 'Downloaded on device ✓'
                                        : 'Will download ML Kit model (~30 MB)',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 11,
                                  color: isDownloaded ? const Color(0xFF3DD68C) : ArcaneTheme.textMuted,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: ArcaneTheme.secondary, size: 20)
                                  : null,
                              onTap: isDownloading
                                  ? null
                                  : () async {
                                      setSheetState(() {});
                                      final ok = await service.setLanguage(lang.code);
                                      if (context.mounted) {
                                        if (ok) {
                                          Navigator.of(context).pop();
                                        } else {
                                          setSheetState(() {});
                                        }
                                      }
                                    },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
