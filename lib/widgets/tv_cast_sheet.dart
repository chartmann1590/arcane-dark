import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../app/theme.dart';
import '../services/tv_cast_service.dart';
import '../services/system_cast_service.dart';
import '../services/audio_service.dart';

enum CastMethod {
  wifiWeb,
  chromecast,
  miracast,
}

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
  CastMethod _selectedMethod = CastMethod.wifiWeb;
  bool _isRunning = TvCastService.instance.isRunning;
  String _castUrl = TvCastService.instance.castUrl;
  int _clients = TvCastService.instance.connectedClientsCount;
  bool _isCompanionMode = false;
  bool _isConnectingCast = false;

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

  Future<void> _launchChromecast() async {
    setState(() => _isConnectingCast = true);
    AudioService.instance.playTap();
    final ok = await SystemCastService.instance.launchChromecastPicker();
    if (mounted) {
      setState(() => _isConnectingCast = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Google Cast & Screen Cast device selector...'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E2235),
          ),
        );
      }
    }
  }

  Future<void> _launchMiracast() async {
    setState(() => _isConnectingCast = true);
    AudioService.instance.playTap();
    final ok = await SystemCastService.instance.launchMiracastPicker();
    if (mounted) {
      setState(() => _isConnectingCast = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scanning for Wireless Display & Miracast TVs...'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E2235),
          ),
        );
      }
    }
  }

  Future<void> _launchInChrome() async {
    AudioService.instance.playTap();
    if (!_isRunning) {
      await _startServer();
    }
    await SystemCastService.instance.launchInChrome(_castUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF10121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
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
                          'BIG SCREEN CASTING',
                          style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(
                          _isRunning ? 'Live Engine Server Active' : 'Select casting method',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11.5,
                            color: _isRunning ? const Color(0xFF3DD68C) : ArcaneTheme.textMuted,
                          ),
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
            const SizedBox(height: 16),

            // Method Selector Segmented Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF161924),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  _buildTabButton(
                    method: CastMethod.wifiWeb,
                    icon: Icons.language_rounded,
                    label: 'Wi-Fi Web',
                  ),
                  const SizedBox(width: 4),
                  _buildTabButton(
                    method: CastMethod.chromecast,
                    icon: Icons.cast_rounded,
                    label: 'Chromecast',
                  ),
                  const SizedBox(width: 4),
                  _buildTabButton(
                    method: CastMethod.miracast,
                    icon: Icons.screen_share_rounded,
                    label: 'Miracast',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tab Content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCurrentTabContent(),
            ),
            const SizedBox(height: 16),

            // Couch Controller Mode switch (common to all modes)
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
                  'Optimizes this phone for chat, voice mic, orders, and D-Pad while the TV displays the 3D map.',
                  style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textSecondary),
                ),
                onChanged: (val) {
                  setState(() => _isCompanionMode = val);
                  widget.onToggleCompanionMode(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required CastMethod method,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () {
          AudioService.instance.playTap();
          setState(() => _selectedMethod = method);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? ArcaneTheme.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ArcaneTheme.secondary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.black : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_selectedMethod) {
      case CastMethod.wifiWeb:
        return _buildWifiWebTab();
      case CastMethod.chromecast:
        return _buildChromecastTab();
      case CastMethod.miracast:
        return _buildMiracastTab();
    }
  }

  // ================= 1. WI-FI WEB TAB =================
  Widget _buildWifiWebTab() {
    if (!_isRunning) {
      return _buildStartServerCard();
    }
    return Column(
      key: const ValueKey('wifi_web_tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // QR & URL Box
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
                'Open this URL in any Smart TV, console, or PC web browser:',
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
                  size: 140.0,
                ),
              ),
              const SizedBox(height: 12),
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
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: ArcaneTheme.secondary,
                      ),
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
        const SizedBox(height: 12),

        // Connected indicator & stop button
        _buildConnectionStatusBar(),
      ],
    );
  }

  // ================= 2. CHROMECAST TAB =================
  Widget _buildChromecastTab() {
    return Column(
      key: const ValueKey('chromecast_tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF181B26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cast_connected_rounded, color: Color(0xFF6BA4FF), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Cast / Chromecast',
                          style: GoogleFonts.cinzel(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Beam live gameplay to Chromecast, Google TV, Android TV, or Nest Hub displays.',
                          style: GoogleFonts.ibmPlexSans(fontSize: 11.5, color: ArcaneTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Action 1: System Cast Picker
              ElevatedButton.icon(
                icon: _isConnectingCast
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cast_rounded, size: 20),
                label: Text(_isConnectingCast ? 'Opening Cast Picker...' : 'Launch Chromecast Device Picker'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: _isConnectingCast ? null : _launchChromecast,
              ),
              const SizedBox(height: 10),

              // Action 2: Open in Chrome for tab cast
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text('Cast Web Stream via Chrome'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8AB4F8),
                  side: const BorderSide(color: Color(0xFF4285F4)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: _launchInChrome,
              ),
              const SizedBox(height: 14),

              // Chromecast perks
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(Icons.check_circle_outline_rounded, 'Streams 3D isometric dungeon & dice rolls at 60 FPS'),
                    const SizedBox(height: 6),
                    _buildFeatureRow(Icons.check_circle_outline_rounded, 'Includes full stereo spatial audio & DM sound effects'),
                    const SizedBox(height: 6),
                    _buildFeatureRow(Icons.security_rounded, 'Using Web Stream keeps your notifications private off TV'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildConnectionStatusBar(),
      ],
    );
  }

  // ================= 3. MIRACAST TAB =================
  Widget _buildMiracastTab() {
    return Column(
      key: const ValueKey('miracast_tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF181B26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2B35A).withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ArcaneTheme.secondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.screen_share_rounded, color: ArcaneTheme.secondary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Miracast / Wireless Display',
                          style: GoogleFonts.cinzel(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Direct Wi-Fi Display peer-to-peer screen mirroring without needing a router or internet.',
                          style: GoogleFonts.ibmPlexSans(fontSize: 11.5, color: ArcaneTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Supported displays chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildBrandChip('Samsung Smart View'),
                  _buildBrandChip('LG Screen Share'),
                  _buildBrandChip('Roku TV'),
                  _buildBrandChip('Fire TV'),
                  _buildBrandChip('Windows 10/11'),
                ],
              ),
              const SizedBox(height: 16),

              // Miracast Connect Button
              ElevatedButton.icon(
                icon: _isConnectingCast
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.settings_remote_rounded, size: 20),
                label: Text(_isConnectingCast ? 'Scanning Displays...' : 'Connect via Wireless Display (Miracast)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ArcaneTheme.secondary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isConnectingCast ? null : _launchMiracast,
              ),
              const SizedBox(height: 14),

              // TV Instructions card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick TV Pairing Steps:',
                      style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary),
                    ),
                    const SizedBox(height: 6),
                    _buildGuideStep('1', 'Samsung: Select "Screen Mirroring" or use Smart View.'),
                    _buildGuideStep('2', 'LG TV: Open "Screen Share" from the Home Dashboard.'),
                    _buildGuideStep('3', 'Roku / Fire TV: Go to Settings > Display > Screen Mirroring.'),
                    _buildGuideStep('4', 'Windows PC: Press Win + K and choose "Cast to this PC".'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildConnectionStatusBar(),
      ],
    );
  }

  Widget _buildBrandChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSans(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildGuideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ArcaneTheme.secondary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ArcaneTheme.secondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.ibmPlexSans(fontSize: 11, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6BA4FF)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.ibmPlexSans(fontSize: 11, color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatusBar() {
    return Container(
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
                  color: _clients > 0 ? const Color(0xFF3DD68C) : (_isRunning ? Colors.amber : Colors.grey),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _clients > 0
                    ? '$_clients TV Display(s) Active'
                    : (_isRunning ? 'Local Engine Server Ready' : 'Server Inactive'),
                style: GoogleFonts.ibmPlexSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          if (_isRunning)
            TextButton(
              onPressed: _stopServer,
              child: const Text('Stop Server', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            )
          else
            TextButton(
              onPressed: _startServer,
              child: const Text('Start Server', style: TextStyle(color: ArcaneTheme.secondary, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildStartServerCard() {
    return Container(
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
    );
  }
}
