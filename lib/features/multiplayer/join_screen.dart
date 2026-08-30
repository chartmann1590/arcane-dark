import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../services/audio_service.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _codeCtrl = TextEditingController();
  String? _error;

  void _join() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      AudioService.instance.playError();
      setState(() => _error = 'Enter a 6-character code (e.g. A7K9P2)');
      return;
    }
    setState(() => _error = null);
    AudioService.instance.playSuccess();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joining party $code...', style: GoogleFonts.manrope()), backgroundColor: ArcaneTheme.primary));
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) context.go('/party');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()), title: Text('JOIN A CAMPAIGN', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: ArcaneTheme.cardDecoration(goldBorder: true),
            child: Column(children: [
              Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: ArcaneTheme.secondary.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.vpn_key_rounded, color: ArcaneTheme.secondary, size: 28)),
              const SizedBox(height: 14),
              Text('Enter Join Code', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Ask your host for the 6-character code shown in their lobby.', textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 13, color: ArcaneTheme.textSecondary)),
              const SizedBox(height: 18),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4, color: Colors.white),
                decoration: InputDecoration(counterText: '', hintText: '— — — — — —', hintStyle: GoogleFonts.manrope(letterSpacing: 6, color: ArcaneTheme.textMuted), errorText: _error),
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _join, child: Text('Join Party', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)))),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HAVING TROUBLE?', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: ArcaneTheme.textMuted)),
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
        Expanded(child: Text(text, style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary))),
      ]),
    );
  }
}
