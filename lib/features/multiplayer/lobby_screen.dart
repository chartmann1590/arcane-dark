import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});
  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String joinCode = '';
  bool isHost = false;
  final players = <Map<String, String>>[
    {'name': 'You (Host)', 'status': 'Ready', 'avatar': '🧙'},
    {'name': 'Waiting...', 'status': 'Empty slot', 'avatar': '—'},
    {'name': 'Waiting...', 'status': 'Empty slot', 'avatar': '—'},
  ];

  @override
  void initState() {
    super.initState();
    joinCode = _genCode();
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(title: Text('PARTY LOBBY', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 13, color: Colors.white)), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Join code card — matches Stitch Multiplayer Lobby
          Container(
            padding: const EdgeInsets.all(18),
            decoration: ArcaneTheme.cardDecoration(goldBorder: true),
            child: Column(children: [
              Text('JOIN CODE', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: ArcaneTheme.textMuted)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: joinCode.split('').map((c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: ArcaneTheme.secondary.withOpacity(0.35))), child: Text(c, style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white)))).toList()),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF3DD68C), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Lobby open — waiting for party', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(onPressed: () => setState(() => joinCode = _genCode()), icon: const Icon(Icons.refresh_rounded, size: 16), label: Text('Regenerate Code', style: GoogleFonts.manrope(fontSize: 12))),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text('PARTY  •  ${players.where((p) => p['status'] == 'Ready').length}/6', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: ArcaneTheme.textMuted)),
            const Spacer(),
            Text('Host • Spark Free', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.secondary, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          ...players.asMap().entries.map((e) {
            final p = e.value;
            final isEmpty = p['status'] == 'Empty slot';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: isEmpty ? ArcaneTheme.surfaceCard.withOpacity(0.6) : ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: isEmpty ? ArcaneTheme.border : ArcaneTheme.primary.withOpacity(0.3))),
                child: Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: isEmpty ? ArcaneTheme.surfaceElevated : ArcaneTheme.primary.withOpacity(0.15), shape: BoxShape.circle), child: Center(child: Text(p['avatar']!, style: const TextStyle(fontSize: 20)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['name']!, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: isEmpty ? ArcaneTheme.textMuted : Colors.white)),
                    Text(p['status']!, style: GoogleFonts.manrope(fontSize: 12, color: isEmpty ? ArcaneTheme.textMuted : const Color(0xFF3DD68C))),
                  ])),
                  if (!isEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF3DD68C).withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text('Ready', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF3DD68C)))),
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Starting adventure — host begins narration!', style: GoogleFonts.manrope()), backgroundColor: ArcaneTheme.primary));
                context.go('/play');
              },
              child: Text('Begin Adventure', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: () => context.push('/join'), child: Text('Join with Code', style: GoogleFonts.manrope())),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: ArcaneTheme.border)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: ArcaneTheme.textMuted),
              const SizedBox(width: 8),
              Expanded(child: Text('On Spark (free) plan: host runs the AI Dungeon Master locally. If the host disconnects, the party waits in “paused”. No Cloud Functions required.', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted))),
            ]),
          ),
        ],
      ),
    );
  }
}
