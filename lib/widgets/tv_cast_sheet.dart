import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../app/theme.dart';
import '../services/tv_cast_service.dart';
import '../services/audio_service.dart';

class TvCastSheet extends StatefulWidget {
  final bool isCompanionMode;
  final ValueChanged<bool> onToggleCompanionMode;

  const TvCastSheet({
    super.key,
    required this.isCompanionMode,
    required this.onToggleCompanionMode,
  });

  @override
  State<TvCastSheet> createState() => _TvCastSheetState();
}

class _TvCastSheetState extends State<TvCastSheet> {
  bool _isRunning = TvCastService.instance.isRunning;
  String _castUrl = TvCastService.instance.castUrl;
  int _clients = TvCastService.instance.connectedClientsCount;
  bool _isCompanionMode = false;

  @override
  void initState() {
    super.initState();
    _isCompanionMode = widget.isCompanionMode;
    if (!_isRunning) {
      _startServer();
    }
  }

  Future<void> _startServer() async {
    final ok = await TvCastService.instance.startServer();
    if (mounted) {
      setState(() {
        _isRunning = ok;
        _castUrl = TvCastService.instance.castUrl;
        _clients = TvCastService.instance.connectedClientsCount;
      });
    }
  }

  Future<void> _stopServer() async {
    await TvCastService.instance.stopServer();
    if (mounted) {
      setState(() {
        _isRunning = false;
        _castUrl = TvCastService.instance.castUrl;
        _clients = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF10121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ArcaneTheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.tv_rounded, color: ArcaneTheme.secondary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TV CAST & BIG SCREEN',
                        style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        _isRunning ? 'Broadcasting live over Wi-Fi' : 'Server stopped',
                        style: GoogleFonts.ibmPlexSans(fontSize: 11.5, color: _isRunning ? const Color(0xFF3DD68C) : ArcaneTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: ArcaneTheme.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (_isRunning) ...[
            // QR Code & Cast URL Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF181B26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Scan with TV camera or open URL in any TV web browser:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: _castUrl,
                      version: QrVersions.auto,
                      size: 150.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // URL pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language_rounded, size: 16, color: ArcaneTheme.secondary),
                        const SizedBox(width: 8),
                        SelectableText(
                          _castUrl,
                          style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy URL'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _castUrl));
                          AudioService.instance.playTap();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cast URL copied to clipboard!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 14),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        onPressed: () {
                          Share.share('Join my Arcane Dark campaign stream on TV: $_castUrl');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Connected displays indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF141722),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _clients > 0 ? const Color(0xFF3DD68C) : Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _clients > 0 ? '$_clients TV Display(s) Active' : 'Waiting for TV connection...',
                        style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _stopServer,
                    child: const Text('Stop Cast', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Big Screen Companion Mode toggle
            Container(
              decoration: BoxDecoration(
                color: _isCompanionMode ? ArcaneTheme.secondary.withValues(alpha: 0.15) : const Color(0xFF141722),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isCompanionMode ? ArcaneTheme.secondary.withValues(alpha: 0.5) : Colors.white12,
                ),
              ),
              child: SwitchListTile(
                value: _isCompanionMode,
                activeThumbColor: ArcaneTheme.secondary,
                title: Text(
                  'Couch Controller & Grimoire Mode',
                  style: GoogleFonts.cinzel(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                subtitle: Text(
                  'Optimizes the phone screen for chat, speech transcription, party orders, and D-Pad while the TV displays the 3D map.',
                  style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textSecondary),
                ),
                onChanged: (val) {
                  setState(() => _isCompanionMode = val);
                  widget.onToggleCompanionMode(val);
                },
              ),
            ),
          ] else ...[
            // Start server button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF181B26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cast_connected_rounded, size: 48, color: ArcaneTheme.secondary),
                  const SizedBox(height: 12),
                  Text(
                    'Cast to your TV or PC',
                    style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Streams the 3D isometric dungeon map, tactical battle arena, dice rolls, and AI story narration live to any big screen in your room.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start TV Cast Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArcaneTheme.secondary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _startServer,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
