import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/theme.dart';
import '../../providers/character_provider.dart';
import '../../services/auth_service.dart';
import '../../services/session_repository.dart';
import '../auth/auth_screen.dart';

/// Real Firestore-backed lobby. If [sessionId] is null this device is hosting
/// (a session is created on first build); otherwise it's watching a session
/// already joined from [JoinScreen].
class LobbyScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  const LobbyScreen({super.key, this.sessionId});
  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  SessionInfo? _session;
  String? _error;
  bool _creating = false;

  bool get isHost => _session != null && _session!.hostUid == AuthService.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId == null) {
      _hostNewSession();
    } else {
      _session = null; // will populate from the watch stream below
    }
  }

  Future<void> _ensureAuthed() async {
    if (AuthService.instance.currentUser != null) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  Future<void> _hostNewSession() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await _ensureAuthed();
      final chars = ref.read(savedCharactersProvider);
      final seedJson = {'title': 'A Shared Adventure', 'tone': 'classic fantasy', 'setting': 'A forgotten dungeon', 'hook': 'The party gathers at the mouth of the ruins.', 'startingLocation': 'The Ruined Gate', 'beats': <String>[]};
      final info = await SessionRepository.instance.createSession(
        campaignSeedJson: seedJson,
        displayName: chars.isNotEmpty ? chars.first.name : 'Host',
        characterId: chars.isNotEmpty ? chars.first.id : null,
      );
      if (!mounted) return;
      setState(() {
        _session = info;
        _creating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creating = false;
      });
    }
  }

  String get _shareText {
    final code = _session?.joinCode ?? widget.sessionId ?? '';
    return 'Join my Arcane Dark party! Open the app, tap Multiplayer → Join with Code, and enter: $code\n\nOr scan the QR code I\'m showing you.';
  }

  @override
  void dispose() {
    final id = _session?.id ?? widget.sessionId;
    if (id != null) SessionRepository.instance.leaveSession(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = widget.sessionId ?? _session?.id;

    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      appBar: AppBar(title: Text('PARTY LOBBY', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 13, color: Colors.white)), centerTitle: true),
      body: _creating
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded, color: ArcaneTheme.tertiary, size: 32),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.manrope(color: ArcaneTheme.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _hostNewSession, child: const Text('Retry')),
                    ]),
                  ),
                )
              : sessionId == null
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<SessionInfo>(
                      stream: SessionRepository.instance.watchSession(sessionId),
                      builder: (context, sessionSnap) {
                        final session = sessionSnap.data ?? _session;
                        return StreamBuilder<List<SessionPlayer>>(
                          stream: SessionRepository.instance.watchPlayers(sessionId),
                          builder: (context, playersSnap) {
                            final players = playersSnap.data ?? const <SessionPlayer>[];
                            final joinCode = session?.joinCode ?? '';
                            return ListView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: ArcaneTheme.cardDecoration(goldBorder: true),
                                  child: Column(children: [
                                    Text('JOIN CODE', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: ArcaneTheme.textMuted)),
                                    const SizedBox(height: 8),
                                    Row(mainAxisAlignment: MainAxisAlignment.center, children: joinCode.split('').map((c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: ArcaneTheme.secondary.withOpacity(0.35))), child: Text(c, style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white)))).toList()),
                                    if (joinCode.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                        child: QrImageView(data: joinCode, size: 160, backgroundColor: Colors.white),
                                      ),
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => SharePlus.instance.share(ShareParams(text: _shareText)),
                                          icon: const Icon(Icons.ios_share_rounded, size: 16),
                                          label: Text('Share Invite', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Container(width: 8, height: 8, decoration: BoxDecoration(color: (session?.status == 'active') ? ArcaneTheme.primary : const Color(0xFF3DD68C), shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text(session?.status == 'active' ? 'Adventure in progress' : 'Lobby open — waiting for party', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary)),
                                    ]),
                                  ]),
                                ),
                                const SizedBox(height: 16),
                                Row(children: [
                                  Text('PARTY  •  ${players.length}/6', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: ArcaneTheme.textMuted)),
                                  const Spacer(),
                                  Text('Host • Spark Free', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.secondary, fontWeight: FontWeight.w600)),
                                ]),
                                const SizedBox(height: 10),
                                ...players.map((p) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(color: ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.primary.withOpacity(0.3))),
                                        child: Row(children: [
                                          Container(width: 44, height: 44, decoration: BoxDecoration(color: ArcaneTheme.primary.withOpacity(0.15), shape: BoxShape.circle), child: Center(child: Text(p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?', style: GoogleFonts.playfairDisplay(color: ArcaneTheme.primary, fontWeight: FontWeight.w800)))),
                                          const SizedBox(width: 12),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text('${p.displayName}${p.uid == session?.hostUid ? " (Host)" : ""}', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
                                            Text(p.ready ? 'Ready' : 'Joining…', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF3DD68C))),
                                          ])),
                                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF3DD68C).withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text('Ready', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF3DD68C)))),
                                        ]),
                                      ),
                                    )),
                                for (var i = players.length; i < 3; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(color: ArcaneTheme.surfaceCard.withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.border)),
                                      child: Row(children: [
                                        Container(width: 44, height: 44, decoration: const BoxDecoration(color: ArcaneTheme.surfaceElevated, shape: BoxShape.circle), child: const Center(child: Text('—'))),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text('Waiting for player…', style: GoogleFonts.manrope(color: ArcaneTheme.textMuted))),
                                      ]),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                if (isHost)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: players.isEmpty
                                          ? null
                                          : () async {
                                              await SessionRepository.instance.startSession(sessionId);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Starting adventure — host begins narration!', style: GoogleFonts.manrope()), backgroundColor: ArcaneTheme.primary));
                                                context.go('/play');
                                              }
                                            },
                                      child: Text('Begin Adventure', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(10)),
                                    child: Text(session?.status == 'active' ? 'The host has begun — rejoin from Play.' : 'Waiting for the host to begin…', textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textSecondary)),
                                  ),
                                const SizedBox(height: 10),
                                if (widget.sessionId == null)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(onPressed: () => context.push('/join'), child: Text('Join a Different Party', style: GoogleFonts.manrope())),
                                  ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: ArcaneTheme.border)),
                                  child: Row(children: [
                                    const Icon(Icons.info_outline_rounded, size: 16, color: ArcaneTheme.textMuted),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('On Spark (free) plan: host runs the AI Dungeon Master locally. If the host disconnects, the party waits in "paused". No Cloud Functions required.', style: GoogleFonts.manrope(fontSize: 11, color: ArcaneTheme.textMuted))),
                                  ]),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
    );
  }
}
