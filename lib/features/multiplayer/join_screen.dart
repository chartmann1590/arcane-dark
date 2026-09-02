import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../app/theme.dart';
import '../../providers/character_provider.dart';
import '../../services/audio_service.dart';
import '../../services/session_repository.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});
  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _codeCtrl = TextEditingController();
  String? _error;
  bool _joining = false;

  Future<void> _join([String? codeOverride]) async {
    final code = (codeOverride ?? _codeCtrl.text).trim().toUpperCase();
    if (code.length != 6) {
      AudioService.instance.playError();
      setState(() => _error = 'Enter a 6-character code (e.g. A7K9P2)');
      return;
    }
    setState(() {
      _error = null;
      _joining = true;
    });
    try {
      final chars = ref.read(savedCharactersProvider);
      final info = await SessionRepository.instance.joinSessionByCode(
        code,
        displayName: chars.isNotEmpty ? chars.first.name : 'Adventurer',
        characterId: chars.isNotEmpty ? chars.first.id : null,
      );
      AudioService.instance.playSuccess();
      if (mounted) context.go('/party?session=${info.id}');
    } catch (e) {
      AudioService.instance.playError();
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _scanQr() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _QrScanScreen()));
    if (code != null && mounted) {
      _codeCtrl.text = code;
      _join(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()), title: Text('JOIN A CAMPAIGN', style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: ArcaneTheme.ornateDecoration(),
            child: Column(children: [
              Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: ArcaneTheme.secondary.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.vpn_key_rounded, color: ArcaneTheme.secondary, size: 28)),
              const SizedBox(height: 14),
              Text('Enter Join Code', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Ask your host for the 6-character code, or scan their QR code.', textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: ArcaneTheme.textSecondary)),
              const SizedBox(height: 18),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4, color: Colors.white),
                decoration: InputDecoration(counterText: '', hintText: '— — — — — —', hintStyle: GoogleFonts.ibmPlexSans(letterSpacing: 6, color: ArcaneTheme.textMuted), errorText: _error),
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _joining ? null : () => _join(),
                  child: _joining ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Join Party', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(onPressed: _joining ? null : _scanQr, icon: const Icon(Icons.qr_code_scanner_rounded, size: 18), label: Text('Scan QR Code', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700))),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HAVING TROUBLE?', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: ArcaneTheme.textMuted)),
              const SizedBox(height: 8),
              _Bullet('Codes refresh each time the host creates a new lobby.'),
              _Bullet('Everyone needs internet — only the host runs the AI.'),
              _Bullet('You can still play solo any time — solo needs no code and works offline.'),
            ]),
          ),
        ],
      ),
    );
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();
  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.length < 4) return;
    _handled = true;
    Navigator.of(context).pop(value.trim().toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text('Scan Party QR Code', style: GoogleFonts.ibmPlexSans(color: Colors.white))),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(margin: const EdgeInsets.only(top: 6), width: 6, height: 6, decoration: const BoxDecoration(color: ArcaneTheme.textMuted, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary))),
      ]),
    );
  }
}
