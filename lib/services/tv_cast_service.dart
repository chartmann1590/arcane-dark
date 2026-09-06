import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service managing the local TV Cast / Big-Screen presentation server.
/// Broadcasts 3D isometric dungeon updates, tactical battle scenes,
/// dice roll cinematics, and DM story narration over local Wi-Fi.
class TvCastService {
  TvCastService._();
  static final TvCastService instance = TvCastService._();

  HttpServer? _server;
  final List<WebSocket> _clients = [];
  String? _localIp;
  int _port = 8484;
  bool _isRunning = false;

  Map<String, dynamic>? _lastStateSnapshot;
  Map<String, dynamic>? _lastCombatSnapshot;
  final List<Map<String, String>> _recentNarration = [];

  bool get isRunning => _isRunning;
  String? get localIp => _localIp;
  int get port => _port;
  int get connectedClientsCount => _clients.length;
  String get castUrl => _localIp != null ? 'http://$_localIp:$_port' : 'http://localhost:$_port';

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  final _clientCountController = StreamController<int>.broadcast();
  Stream<int> get clientCountStream => _clientCountController.stream;

  Future<bool> startServer({int port = 8484}) async {
    if (_isRunning) return true;
    _port = port;

    try {
      _localIp = await _findLocalIp();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;
      _statusController.add(true);
      debugPrint('[TvCastService] TV Cast server live at http://${_localIp ?? "0.0.0.0"}:$_port');

      _server!.listen((HttpRequest req) async {
        if (req.uri.path == '/ws') {
          if (WebSocketTransformer.isUpgradeRequest(req)) {
            final socket = await WebSocketTransformer.upgrade(req);
            _handleWebSocket(socket);
          } else {
            req.response
              ..statusCode = HttpStatus.badRequest
              ..write('Expected WebSocket upgrade request.')
              ..close();
          }
        } else if (req.uri.path == '/status') {
          req.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'status': 'online',
              'server': 'Arcane Dark TV Cast',
              'clients': _clients.length,
            }))
            ..close();
        } else {
          // Serve TV Web App HTML
          req.response
            ..headers.contentType = ContentType.html
            ..write(_generateTvHtml())
            ..close();
        }
      });

      return true;
    } catch (e) {
      debugPrint('[TvCastService] Failed to start server: $e');
      _isRunning = false;
      _statusController.add(false);
      return false;
    }
  }

  Future<void> stopServer() async {
    for (final client in _clients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();
    _clientCountController.add(0);

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _isRunning = false;
    _statusController.add(false);
    debugPrint('[TvCastService] TV Cast server stopped.');
  }

  void _handleWebSocket(WebSocket socket) {
    _clients.add(socket);
    _clientCountController.add(_clients.length);
    debugPrint('[TvCastService] TV client connected (${_clients.length} total)');

    // Send initial snapshot
    if (_lastStateSnapshot != null) {
      socket.add(jsonEncode({
        'type': 'state',
        'data': _lastStateSnapshot,
      }));
    }
    if (_lastCombatSnapshot != null) {
      socket.add(jsonEncode({
        'type': 'combat',
        'data': _lastCombatSnapshot,
      }));
    }
    if (_recentNarration.isNotEmpty) {
      socket.add(jsonEncode({
        'type': 'narration_history',
        'data': _recentNarration,
      }));
    }

    socket.listen(
      (message) {
        // TV clients can send ping or camera controls if needed
      },
      onDone: () {
        _clients.remove(socket);
        _clientCountController.add(_clients.length);
        debugPrint('[TvCastService] TV client disconnected (${_clients.length} remaining)');
      },
      onError: (err) {
        _clients.remove(socket);
        _clientCountController.add(_clients.length);
      },
      cancelOnError: true,
    );
  }

  void broadcastState(Map<String, dynamic> stateData) {
    _lastStateSnapshot = stateData;
    _broadcast({
      'type': 'state',
      'data': stateData,
    });
  }

  void broadcastCombat(Map<String, dynamic>? combatData) {
    _lastCombatSnapshot = combatData;
    _broadcast({
      'type': 'combat',
      'data': combatData,
    });
  }

  void broadcastNarration(String speaker, String text) {
    final entry = {
      'speaker': speaker,
      'text': text,
      'time': DateTime.now().toIso8601String(),
    };
    _recentNarration.add(entry);
    if (_recentNarration.length > 20) {
      _recentNarration.removeAt(0);
    }
    _broadcast({
      'type': 'narration',
      'data': entry,
    });
  }

  void broadcastDiceRoll({
    required String roller,
    required String reason,
    required int d20,
    required int modifier,
    required int total,
  }) {
    _broadcast({
      'type': 'dice_roll',
      'data': {
        'roller': roller,
        'reason': reason,
        'd20': d20,
        'modifier': modifier,
        'total': total,
        'isCrit': d20 == 20,
        'isFumble': d20 == 1,
      },
    });
  }

  void _broadcast(Map<String, dynamic> payload) {
    if (_clients.isEmpty) return;
    final jsonStr = jsonEncode(payload);
    for (final client in List<WebSocket>.from(_clients)) {
      try {
        client.add(jsonStr);
      } catch (e) {
        _clients.remove(client);
        _clientCountController.add(_clients.length);
      }
    }
  }

  Future<String?> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String _generateTvHtml() {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Arcane Dark — Big Screen TV Cast</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700;800;900&family=IBM+Plex+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; }
    body {
      background-color: #0A0B10;
      color: #E2E8F0;
      font-family: 'IBM Plex Sans', sans-serif;
      overflow: hidden;
      width: 100vw;
      height: 100vh;
      display: flex;
      flex-direction: column;
    }
    /* Top Header Bar */
    header {
      height: 70px;
      background: linear-gradient(180deg, rgba(16, 18, 26, 0.95) 0%, rgba(10, 11, 16, 0.8) 100%);
      border-bottom: 1px solid rgba(226, 179, 90, 0.25);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 32px;
      z-index: 10;
    }
    .header-left {
      display: flex;
      align-items: center;
      gap: 16px;
    }
    .logo-badge {
      font-family: 'Cinzel', serif;
      font-size: 24px;
      font-weight: 900;
      letter-spacing: 2px;
      color: #E2B35A;
      text-shadow: 0 0 16px rgba(226, 179, 90, 0.4);
    }
    .quest-pill {
      background: rgba(226, 179, 90, 0.12);
      border: 1px solid rgba(226, 179, 90, 0.35);
      border-radius: 20px;
      padding: 6px 16px;
      font-size: 13px;
      font-weight: 600;
      color: #F8D688;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .header-right {
      display: flex;
      align-items: center;
      gap: 16px;
    }
    .live-badge {
      background: #E53935;
      color: #FFF;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 1.5px;
      padding: 4px 10px;
      border-radius: 12px;
      text-transform: uppercase;
      animation: pulse 2s infinite ease-in-out;
    }
    @keyframes pulse {
      0%, 100% { opacity: 0.9; transform: scale(1); }
      50% { opacity: 0.5; transform: scale(0.96); }
    }
    /* Main Content Area */
    main {
      flex: 1;
      display: flex;
      position: relative;
      overflow: hidden;
    }
    /* Dungeon Map Canvas Viewport */
    #mapViewport {
      flex: 1;
      height: 100%;
      position: relative;
      background: radial-gradient(circle at center, #181B26 0%, #08090E 100%);
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }
    canvas#dungeonCanvas {
      width: 100%;
      height: 100%;
      display: block;
    }
    /* Right Side Narrative & Party Panel */
    #sidePanel {
      width: 440px;
      background: rgba(16, 18, 26, 0.85);
      border-left: 1px solid rgba(255, 255, 255, 0.08);
      display: flex;
      flex-direction: column;
      backdrop-filter: blur(12px);
      z-index: 5;
    }
    .panel-section {
      padding: 20px 24px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    }
    .section-title {
      font-family: 'Cinzel', serif;
      font-size: 13px;
      font-weight: 800;
      letter-spacing: 1.5px;
      color: #A0AEC0;
      text-transform: uppercase;
      margin-bottom: 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    /* Party Cards */
    .party-grid {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .party-card {
      background: rgba(26, 30, 44, 0.7);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 12px;
      padding: 10px 14px;
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .party-card.active-turn {
      border-color: #E2B35A;
      box-shadow: 0 0 14px rgba(226, 179, 90, 0.3);
    }
    .party-avatar {
      width: 44px;
      height: 44px;
      border-radius: 50%;
      border: 2px solid #E2B35A;
      object-fit: cover;
      background: #111;
    }
    .party-info {
      flex: 1;
    }
    .party-name {
      font-family: 'Cinzel', serif;
      font-size: 14px;
      font-weight: 700;
      color: #FFF;
    }
    .party-role {
      font-size: 11px;
      color: #A0AEC0;
      margin-bottom: 4px;
    }
    .hp-bar-bg {
      height: 6px;
      background: rgba(255, 255, 255, 0.1);
      border-radius: 3px;
      overflow: hidden;
    }
    .hp-bar-fill {
      height: 100%;
      background: #3DD68C;
      border-radius: 3px;
      transition: width 0.4s ease;
    }
    .hp-text {
      font-size: 10px;
      color: #718096;
      text-align: right;
      margin-top: 2px;
    }
    /* Live Story Narration Feed */
    #narrationFeed {
      flex: 1;
      padding: 20px 24px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 16px;
      scroll-behavior: smooth;
    }
    .narration-bubble {
      background: rgba(22, 26, 38, 0.6);
      border-left: 3px solid #E2B35A;
      border-radius: 0 10px 10px 0;
      padding: 12px 16px;
      font-size: 13.5px;
      line-height: 1.55;
      color: #E2E8F0;
      animation: fadeIn 0.4s ease;
    }
    .narration-speaker {
      font-family: 'Cinzel', serif;
      font-size: 11px;
      font-weight: 800;
      color: #E2B35A;
      letter-spacing: 1px;
      margin-bottom: 4px;
      text-transform: uppercase;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(8px); }
      to { opacity: 1; transform: translateY(0); }
    }
    /* Big Screen Tactical Combat Overlay */
    #combatArena {
      display: none;
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(8, 9, 14, 0.94);
      backdrop-filter: blur(16px);
      z-index: 20;
      flex-direction: column;
      padding: 36px 48px;
      animation: fadeIn 0.5s ease;
    }
    .combat-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;
      border-bottom: 1px solid rgba(239, 68, 68, 0.3);
      padding-bottom: 16px;
    }
    .combat-title {
      font-family: 'Cinzel', serif;
      font-size: 28px;
      font-weight: 900;
      color: #F87171;
      letter-spacing: 2px;
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .intent-banner {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.4);
      border-radius: 10px;
      padding: 10px 20px;
      font-size: 14px;
      font-weight: 600;
      color: #FECACA;
    }
    .combat-body {
      flex: 1;
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 36px;
      align-items: center;
    }
    .enemy-card {
      background: radial-gradient(circle at top, rgba(55, 16, 24, 0.7) 0%, rgba(20, 10, 14, 0.9) 100%);
      border: 2px solid rgba(239, 68, 68, 0.4);
      border-radius: 20px;
      padding: 32px;
      text-align: center;
      box-shadow: 0 0 32px rgba(239, 68, 68, 0.2);
    }
    .enemy-avatar {
      width: 140px;
      height: 140px;
      border-radius: 50%;
      border: 4px solid #EF4444;
      object-fit: cover;
      margin: 0 auto 16px;
      box-shadow: 0 0 24px rgba(239, 68, 68, 0.4);
    }
    .enemy-name {
      font-family: 'Cinzel', serif;
      font-size: 26px;
      font-weight: 900;
      color: #FFF;
      margin-bottom: 6px;
    }
    .enemy-role {
      font-size: 14px;
      color: #FCA5A5;
      margin-bottom: 20px;
    }
    .enemy-hp-bar {
      height: 14px;
      background: rgba(255, 255, 255, 0.1);
      border-radius: 7px;
      overflow: hidden;
      margin-bottom: 8px;
    }
    .enemy-hp-fill {
      height: 100%;
      background: #EF4444;
      border-radius: 7px;
      transition: width 0.4s ease;
    }
    .combat-log-card {
      background: rgba(16, 18, 26, 0.8);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 16px;
      padding: 24px;
      height: 100%;
      max-height: 480px;
      display: flex;
      flex-direction: column;
    }
    .combat-log-title {
      font-family: 'Cinzel', serif;
      font-size: 15px;
      font-weight: 800;
      color: #A0AEC0;
      letter-spacing: 1px;
      margin-bottom: 12px;
    }
    .combat-log-feed {
      flex: 1;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .combat-log-entry {
      font-size: 13.5px;
      color: #E2E8F0;
      padding: 8px 12px;
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.03);
    }
    /* Dice Roll Cinematic Overlay */
    #diceCinema {
      display: none;
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0, 0, 0, 0.75);
      z-index: 50;
      align-items: center;
      justify-content: center;
      animation: fadeIn 0.2s ease;
    }
    .dice-box {
      text-align: center;
      animation: slamDown 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
    }
    @keyframes slamDown {
      0% { transform: scale(2.5) rotate(-30deg); opacity: 0; }
      100% { transform: scale(1) rotate(0deg); opacity: 1; }
    }
    .dice-value {
      font-family: 'Cinzel', serif;
      font-size: 96px;
      font-weight: 900;
      color: #E2B35A;
      text-shadow: 0 0 40px rgba(226, 179, 90, 0.8), 0 0 80px rgba(226, 179, 90, 0.4);
    }
    .dice-reason {
      font-family: 'Cinzel', serif;
      font-size: 22px;
      font-weight: 700;
      color: #FFF;
      letter-spacing: 2px;
      margin-top: 10px;
    }
    .dice-detail {
      font-size: 16px;
      color: #A0AEC0;
      margin-top: 6px;
    }
  </style>
</head>
<body>
  <header>
    <div class="header-left">
      <div class="logo-badge">ARCANE DARK</div>
      <div class="quest-pill" id="questPill">
        <span>⚔️</span>
        <span id="questTitle">Delving Dungeon Depth 1</span>
      </div>
    </div>
    <div class="header-right">
      <div class="live-badge">TV CAST LIVE</div>
    </div>
  </header>

  <main>
    <div id="mapViewport">
      <canvas id="dungeonCanvas"></canvas>
    </div>

    <div id="sidePanel">
      <div class="panel-section">
        <div class="section-title">
          <span>Party Formation</span>
          <span id="depthLabel" style="color: #E2B35A;">Depth 1</span>
        </div>
        <div class="party-grid" id="partyGrid">
          <!-- Dynamically populated party cards -->
        </div>
      </div>

      <div class="panel-section" style="border-bottom: none; padding-bottom: 0;">
        <div class="section-title">Chronicle of Deeds</div>
      </div>
      <div id="narrationFeed">
        <!-- Live DM story narration -->
      </div>
    </div>

    <!-- Big Screen Tactical Combat Arena -->
    <div id="combatArena">
      <div class="combat-header">
        <div class="combat-title">
          <span>⚔️ TACTICAL BATTLE ARENA</span>
          <span id="combatRound" style="font-size: 16px; color: #FCA5A5; font-weight: 700;">ROUND 1</span>
        </div>
        <div class="intent-banner" id="combatIntent">⚠️ ENEMY INTENT: Hostile Aggression</div>
      </div>
      <div class="combat-body">
        <div class="enemy-card">
          <div style="font-size: 72px; margin-bottom: 12px;">👹</div>
          <div class="enemy-name" id="enemyName">Dungeon Foe</div>
          <div class="enemy-role" id="enemyRole">Hostile Stalker • AC 12</div>
          <div class="enemy-hp-bar">
            <div class="enemy-hp-fill" id="enemyHpFill" style="width: 100%;"></div>
          </div>
          <div id="enemyHpText" style="font-size: 13px; color: #FCA5A5;">16 / 16 HP</div>
        </div>
        <div class="combat-log-card">
          <div class="combat-log-title">Tactical Action Log</div>
          <div class="combat-log-feed" id="combatLogFeed"></div>
        </div>
      </div>
    </div>

    <!-- Dice Roll Splash Overlay -->
    <div id="diceCinema">
      <div class="dice-box">
        <div class="dice-value" id="diceVal">20</div>
        <div class="dice-reason" id="diceReason">PERCEPTION CHECK</div>
        <div class="dice-detail" id="diceDetail">Roll: 17 + Modifier: 3 = Total: 20</div>
      </div>
    </div>
  </main>

  <script>
    const canvas = document.getElementById('dungeonCanvas');
    const ctx = canvas.getContext('2d');
    let gameState = null;
    let cameraX = 0, cameraY = 0;
    let targetCamX = 0, targetCamY = 0;

    function resizeCanvas() {
      canvas.width = canvas.parentElement.clientWidth;
      canvas.height = canvas.parentElement.clientHeight;
    }
    window.addEventListener('resize', resizeCanvas);
    resizeCanvas();

    // WebSocket Connection
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = protocol + '//' + window.location.host + '/ws';
    let socket = null;

    function connectWs() {
      socket = new WebSocket(wsUrl);
      socket.onopen = () => console.log('[TV Cast] Connected to phone host');
      socket.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          handleMessage(msg);
        } catch(e) {
          console.error(e);
        }
      };
      socket.onclose = () => {
        console.log('[TV Cast] Disconnected, retrying in 2s...');
        setTimeout(connectWs, 2000);
      };
    }
    connectWs();

    function handleMessage(msg) {
      if (msg.type === 'state') {
        gameState = msg.data;
        updateHud(msg.data);
      } else if (msg.type === 'combat') {
        updateCombat(msg.data);
      } else if (msg.type === 'narration') {
        addNarration(msg.data);
      } else if (msg.type === 'narration_history') {
        msg.data.forEach(n => addNarration(n, false));
      } else if (msg.type === 'dice_roll') {
        showDiceCinema(msg.data);
      }
    }

    function updateHud(state) {
      if (!state) return;
      if (state.quest) {
        document.getElementById('questTitle').textContent = state.quest;
      }
      if (state.depth) {
        document.getElementById('depthLabel').textContent = 'Depth ' + state.depth;
      }
      if (state.party) {
        const grid = document.getElementById('partyGrid');
        grid.innerHTML = '';
        state.party.forEach(p => {
          const card = document.createElement('div');
          card.className = 'party-card';
          const hpPct = Math.max(0, Math.min(100, (p.hp / p.maxHp) * 100));
          card.innerHTML = `
            <div style="font-size: 28px;">\${p.icon || '🛡️'}</div>
            <div class="party-info">
              <div class="party-name">\${p.name}</div>
              <div class="party-role">\${p.role || p.raceClass || 'Adventurer'}</div>
              <div class="hp-bar-bg">
                <div class="hp-bar-fill" style="width: \${hpPct}%;"></div>
              </div>
              <div class="hp-text">\${p.hp} / \${p.maxHp} HP</div>
            </div>
          `;
          grid.appendChild(card);
        });
      }
    }

    function updateCombat(combat) {
      const arena = document.getElementById('combatArena');
      if (!combat || !combat.active) {
        arena.style.display = 'none';
        return;
      }
      arena.style.display = 'flex';
      document.getElementById('combatRound').textContent = 'ROUND ' + (combat.round || 1);
      document.getElementById('combatIntent').textContent = combat.intent || '⚠️ ENEMY INTENT: Aggressive Assault';
      document.getElementById('enemyName').textContent = combat.enemyName || 'Dungeon Foe';
      document.getElementById('enemyRole').textContent = (combat.enemyRole || 'Hostile Stalker') + ' • AC ' + (combat.enemyAc || 12);
      
      const hpPct = Math.max(0, Math.min(100, (combat.enemyHp / combat.enemyMaxHp) * 100));
      document.getElementById('enemyHpFill').style.width = hpPct + '%';
      document.getElementById('enemyHpText').textContent = combat.enemyHp + ' / ' + combat.enemyMaxHp + ' HP';

      const logFeed = document.getElementById('combatLogFeed');
      logFeed.innerHTML = '';
      if (combat.logs) {
        combat.logs.forEach(log => {
          const entry = document.createElement('div');
          entry.className = 'combat-log-entry';
          entry.textContent = log;
          logFeed.appendChild(entry);
        });
        logFeed.scrollTop = logFeed.scrollHeight;
      }
    }

    function addNarration(entry, scroll = true) {
      const feed = document.getElementById('narrationFeed');
      const bubble = document.createElement('div');
      bubble.className = 'narration-bubble';
      bubble.innerHTML = `
        <div class="narration-speaker">\${entry.speaker}</div>
        <div>\${entry.text}</div>
      `;
      feed.appendChild(bubble);
      if (scroll) {
        feed.scrollTop = feed.scrollHeight;
      }
    }

    function showDiceCinema(data) {
      const cinema = document.getElementById('diceCinema');
      const valEl = document.getElementById('diceVal');
      const reasonEl = document.getElementById('diceReason');
      const detailEl = document.getElementById('diceDetail');

      valEl.textContent = data.total;
      valEl.style.color = data.isCrit ? '#3DD68C' : (data.isFumble ? '#EF4444' : '#E2B35A');
      reasonEl.textContent = data.reason.toUpperCase();
      detailEl.textContent = 'D20 Roll: ' + data.d20 + '  +  Modifier: ' + (data.modifier >= 0 ? '+' : '') + data.modifier + '  =  Total ' + data.total;

      cinema.style.display = 'flex';
      setTimeout(() => {
        cinema.style.display = 'none';
      }, 3000);
    }

    // Isometric Map Render Loop
    function render() {
      requestAnimationFrame(render);
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      if (!gameState || !gameState.playerPos) {
        ctx.fillStyle = '#718096';
        ctx.font = '16px "IBM Plex Sans", sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('Waiting for Arcane Dark dungeon stream...', canvas.width / 2, canvas.height / 2);
        return;
      }

      const tileW = 64;
      const tileH = 32;
      const wallRise = 32;

      // Smooth camera interpolation
      const heroIsoX = (gameState.playerPos.x - gameState.playerPos.y) * (tileW / 2);
      const heroIsoY = (gameState.playerPos.x + gameState.playerPos.y) * (tileH / 2);
      targetCamX = canvas.width / 2 - heroIsoX;
      targetCamY = canvas.height / 2 - heroIsoY;
      cameraX += (targetCamX - cameraX) * 0.08;
      cameraY += (targetCamY - cameraY) * 0.08;

      ctx.save();
      ctx.translate(cameraX, cameraY);

      // Render Visited Floor Tiles
      if (gameState.visited) {
        gameState.visited.forEach(posKey => {
          const [x, y] = posKey.split(',').map(Number);
          const isoX = (x - y) * (tileW / 2);
          const isoY = (x + y) * (tileH / 2);

          // Floor diamond
          ctx.beginPath();
          ctx.moveTo(isoX, isoY);
          ctx.lineTo(isoX + tileW / 2, isoY + tileH / 2);
          ctx.lineTo(isoX, isoY + tileH);
          ctx.lineTo(isoX - tileW / 2, isoY + tileH / 2);
          ctx.closePath();
          ctx.fillStyle = '#221915';
          ctx.fill();
          ctx.strokeStyle = '#382A22';
          ctx.lineWidth = 1;
          ctx.stroke();

          // Flagstone mortar accent
          ctx.fillStyle = '#453528';
          ctx.fillRect(isoX - 2, isoY + tileH / 2 - 2, 4, 4);
        });
      }

      // Render 3D Walls
      if (gameState.walls) {
        gameState.walls.forEach(w => {
          const isoX = (w.x - w.y) * (tileW / 2);
          const isoY = (w.x + w.y) * (tileH / 2);

          // Front-Left Face (shaded dark)
          ctx.beginPath();
          ctx.moveTo(isoX - tileW / 2, isoY + tileH / 2 - wallRise);
          ctx.lineTo(isoX, isoY + tileH - wallRise);
          ctx.lineTo(isoX, isoY + tileH);
          ctx.lineTo(isoX - tileW / 2, isoY + tileH / 2);
          ctx.closePath();
          ctx.fillStyle = '#1D1E24';
          ctx.fill();
          ctx.strokeStyle = '#0B0D12';
          ctx.stroke();

          // Front-Right Face (lit masonry)
          ctx.beginPath();
          ctx.moveTo(isoX, isoY + tileH - wallRise);
          ctx.lineTo(isoX + tileW / 2, isoY + tileH / 2 - wallRise);
          ctx.lineTo(isoX + tileW / 2, isoY + tileH / 2);
          ctx.lineTo(isoX, isoY + tileH);
          ctx.closePath();
          ctx.fillStyle = '#2A2C35';
          ctx.fill();
          ctx.strokeStyle = '#0B0D12';
          ctx.stroke();

          // Top Face (beveled capstone)
          ctx.beginPath();
          ctx.moveTo(isoX, isoY - wallRise);
          ctx.lineTo(isoX + tileW / 2, isoY + tileH / 2 - wallRise);
          ctx.lineTo(isoX, isoY + tileH - wallRise);
          ctx.lineTo(isoX - tileW / 2, isoY + tileH / 2 - wallRise);
          ctx.closePath();
          ctx.fillStyle = '#3E424E';
          ctx.fill();
          ctx.strokeStyle = '#4F5463';
          ctx.stroke();
        });
      }

      // Render Props (Chests, Tables, Statues, Bones)
      if (gameState.props) {
        gameState.props.forEach(p => {
          const isoX = (p.x - p.y) * (tileW / 2);
          const isoY = (p.x + p.y) * (tileH / 2) + tileH / 2;

          // Drop shadow
          ctx.beginPath();
          ctx.ellipse(isoX, isoY + 4, 14, 7, 0, 0, Math.PI * 2);
          ctx.fillStyle = 'rgba(0,0,0,0.45)';
          ctx.fill();

          // Prop Icon
          ctx.font = '20px "IBM Plex Sans"';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'bottom';
          let icon = '📦';
          if (p.asset.includes('chest')) icon = '🪙';
          else if (p.asset.includes('table')) icon = '🪵';
          else if (p.asset.includes('statue')) icon = '🗿';
          else if (p.asset.includes('bones')) icon = '💀';
          else if (p.asset.includes('crystal')) icon = '💎';
          ctx.fillText(icon, isoX, isoY + 2);
        });
      }

      // Render Hero & Companion Tokens
      if (gameState.playerPos) {
        const hIsoX = (gameState.playerPos.x - gameState.playerPos.y) * (tileW / 2);
        const hIsoY = (gameState.playerPos.x + gameState.playerPos.y) * (tileH / 2) + tileH / 2;

        // Radiant glow
        ctx.beginPath();
        ctx.arc(hIsoX, hIsoY, 20, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(226, 179, 90, 0.25)';
        ctx.fill();

        // Contact shadow
        ctx.beginPath();
        ctx.ellipse(hIsoX, hIsoY + 6, 16, 8, 0, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(0,0,0,0.6)';
        ctx.fill();

        // Hero token badge
        ctx.beginPath();
        ctx.arc(hIsoX, hIsoY - 8, 14, 0, Math.PI * 2);
        ctx.fillStyle = '#E2B35A';
        ctx.fill();
        ctx.strokeStyle = '#FFF';
        ctx.lineWidth = 2;
        ctx.stroke();

        ctx.fillStyle = '#0A0B10';
        ctx.font = 'bold 12px "Cinzel"';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('YOU', hIsoX, hIsoY - 7);
      }

      ctx.restore();
    }
    render();
  </script>
</body>
</html>
''';
  }
}
