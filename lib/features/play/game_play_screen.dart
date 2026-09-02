import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../domain/map/dungeon_generator.dart';
import '../../domain/map/tile_types.dart' as m;
import '../../providers/campaign_provider.dart';
import '../../providers/character_provider.dart';
import '../../providers/settings_provider.dart';
import '../../domain/campaign_seed.dart';
import '../../domain/campaign_state.dart';
import '../../domain/character.dart';
import '../../domain/dm_turn_engine.dart';
import '../../services/audio_service.dart';
import '../../services/session_repository.dart';
import '../../services/tts_service.dart';
import '../../widgets/fx.dart';
import 'iso_map_view.dart';
import 'tavern_populator.dart';

class GamePlayScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  const GamePlayScreen({super.key, this.sessionId});
  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final TransformationController _mapController = TransformationController();
  bool _isGenerating = false;
  String _streamingText = '';
  late m.DungeonMap _dungeon;
  late int _seed;
  bool _mapInitialized = false;
  // Only used when there's no active campaign (ad-hoc dungeon crawl) — a real
  // campaign's map seed lives on CampaignState.mapSeed instead, so it survives
  // navigating away from and back to this screen.
  late int _adHocSeed;
  List<MapNpc> _npcs = [];
  List<MapProp> _props = [];
  Set<String> visited = {};
  m.Point playerPos = const m.Point(5, 5);
  List<Map<String, String>> chat = [];

  // Multiplayer: null until resolved (solo, or resolving host/guest role).
  // Host runs the real DM engine for both its own input and guests' submitted
  // actions; a guest never touches the model — it submits via Firestore and
  // renders whatever the host syncs back.
  bool? _isMultiplayerHost;
  StreamSubscription<Map<String, dynamic>?>? _stateSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _actionsSub;
  int _renderedTurnCount = 0;

  // The isometric canvas is much bigger than the viewport (InteractiveViewer
  // is unconstrained so panning works), so "zoom" is relative to a baked-in
  // fit scale rather than 1.0 — see _recenterOnPlayer.
  static const _baseFitScale = 0.65;
  static const _minZoom = 0.22;
  static const _maxZoom = 2.2;
  bool _mapCentered = false;
  bool _recenterScheduled = false;

  double get _currentZoom => _mapController.value.getMaxScaleOnAxis();

  void _zoomBy(double factor) {
    final current = _currentZoom;
    final target = (current * factor).clamp(_minZoom, _maxZoom);
    final applied = target / current;
    // Scale around the viewport center so zooming feels anchored, not like it
    // yanks the view toward a corner.
    final center = Offset(_mapViewportSize.width / 2, _mapViewportSize.height / 2);
    final m = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(applied)
      ..translate(-center.dx, -center.dy);
    setState(() => _mapController.value = m * _mapController.value);
  }

  void _recenterOnPlayer() {
    // The isometric canvas is unconstrained and much bigger than the
    // viewport, so "recenter" means: compute where the player's diamond
    // actually lands on that canvas, then build a transform that scales to
    // the base fit and translates so that point sits in the viewport center.
    const outerPadding = 8.0; // matches the Padding wrapping IsoMapView
    final originX = _dungeon.height * IsoMapView.tileW / 2;
    const originY = IsoMapView.tileH / 2;
    final playerScreen = Offset(
      outerPadding + originX + (playerPos.x - playerPos.y) * IsoMapView.tileW / 2 + IsoMapView.tileW / 2,
      outerPadding + originY + (playerPos.x + playerPos.y) * IsoMapView.tileH / 2 + IsoMapView.tileH / 2,
    );
    final viewportCenter = Offset(_mapViewportSize.width / 2, _mapViewportSize.height / 2);
    final matrix = Matrix4.identity()
      ..translate(viewportCenter.dx, viewportCenter.dy)
      ..scale(_baseFitScale)
      ..translate(-playerScreen.dx, -playerScreen.dy);
    setState(() {
      _mapController.value = matrix;
      _mapCentered = true;
    });
  }

  Size _mapViewportSize = const Size(360, 280);

  /// Regenerating the dungeon on every build/visit was the bug — the map must
  /// stay the same for a given campaign until an explicit "New Dungeon" or a
  /// brand-new campaign changes its seed. Deterministic generation from a
  /// seed that's persisted on CampaignState (and synced for multiplayer)
  /// means revisiting this screen reconstructs the identical layout.
  void _ensureMapForCampaign(CampaignState? campaign) {
    final targetSeed = campaign?.mapSeed ?? _adHocSeed;
    if (_mapInitialized && _seed == targetSeed) return;
    _seed = targetSeed;
    _dungeon = DungeonGenerator().generate(seed: _seed, width: 18, height: 18);
    if (campaign != null) {
      playerPos = m.Point(campaign.partyPosition.x, campaign.partyPosition.y);
      visited = campaign.visitedTiles.isNotEmpty ? Set<String>.from(campaign.visitedTiles) : {'${playerPos.x},${playerPos.y}'};
    } else {
      playerPos = m.Point(_dungeon.entryPoint.x, _dungeon.entryPoint.y);
      visited = {'${playerPos.x},${playerPos.y}'};
    }
    if ((campaign?.mapEnvironment ?? 'dungeon') == 'tavern') {
      _npcs = generateTavernNpcs(_dungeon);
      _props = generateTavernProps(_dungeon, _npcs);
    } else {
      _npcs = [];
      _props = [];
    }
    _mapInitialized = true;
    _mapCentered = false;
  }

  // Phrases that mean "a brand-new area", not just "still wandering the same
  // one" — descending, moving on to a new chamber, etc. Checked only while
  // already in the dungeon environment, so ordinary movement narration
  // doesn't reroll the map on every single turn.
  static const _progressionWords = ['descend', 'deeper', 'further in', 'further into', 'next chamber', 'another room', 'another chamber', 'press onward', 'venture further', 'delve deeper', 'new chamber', 'new area', 'new passage', 'leave the crypt', 'exit the dungeon', 'emerge from', 'return to the surface', 'back outside', 'back at'];

  /// Re-derives the environment from the DM's own narration every turn (not
  /// just once at campaign start) — walking into a shop or out into the
  /// wilds actually changes what the map looks like. Switching TYPES
  /// (tavern <-> dungeon) reuses that type's remembered seed if the party's
  /// been there before in this campaign (same building, same NPCs/furniture).
  /// Progressing deeper *within* the dungeon type instead rolls a genuinely
  /// new map each time — a real sequence of distinct areas, not one map
  /// reused forever — while still remembering the hub (tavern) to return to.
  void _switchEnvironmentIfNeeded(CampaignState campaign, String narrationText) {
    final detected = CampaignState.environmentFor(narrationText);
    final lower = narrationText.toLowerCase();
    final depth = campaign.worldFlags['dungeonDepth'] as int? ?? 0;

    String newLocationKey;
    if (detected == 'dungeon' && campaign.mapEnvironment == 'dungeon' && _progressionWords.any(lower.contains)) {
      final nextDepth = depth + 1;
      campaign.worldFlags['dungeonDepth'] = nextDepth;
      newLocationKey = 'dungeon_$nextDepth';
    } else if (detected == 'dungeon') {
      newLocationKey = depth > 0 ? 'dungeon_$depth' : 'dungeon';
    } else {
      newLocationKey = detected; // 'tavern' — one stable remembered hub
    }

    final currentKey = campaign.mapEnvironment == 'dungeon' && depth > 0 ? 'dungeon_$depth' : campaign.mapEnvironment;
    if (newLocationKey == currentKey) return;

    campaign.mapEnvironment = detected;
    campaign.mapSeed = campaign.seedForEnvironment(newLocationKey);
    campaign.partyPosition = const Point(5, 5);
    campaign.visitedTiles = {};
    // A new map means everyone's independent wandering positions from the
    // old one are meaningless — reset to re-cluster at the new entry point.
    for (final member in campaign.party) {
      member.position = null;
    }
  }

  /// AI companions have their own mind between turns too: each one might
  /// wander to an adjacent walkable tile near the party rather than
  /// teleporting in lockstep with the player — a small, real simulation of
  /// "they act on their own," not just narration. The DM's own
  /// move_companion action (see DmTools) can also place one explicitly when
  /// the story calls for it; this just fills in the quiet moments.
  void _wanderCompanions(CampaignState campaign) {
    if (campaign.party.length <= 1) return;
    final rng = Random();
    for (var i = 1; i < campaign.party.length; i++) {
      if (rng.nextDouble() > 0.5) continue; // not every companion moves every turn
      final member = campaign.party[i];
      final from = member.position ?? campaign.partyPosition;
      final candidates = <Point>[
        Point(from.x + 1, from.y),
        Point(from.x - 1, from.y),
        Point(from.x, from.y + 1),
        Point(from.x, from.y - 1),
      ].where((p) {
        if (p.x < 0 || p.y < 0 || p.x >= _dungeon.width || p.y >= _dungeon.height) return false;
        final tile = _dungeon.tileAt(p.x, p.y);
        if (tile == m.TileType.wall || tile == m.TileType.water) return false;
        // Stay within a couple tiles of the lead — wandering, not wandering off.
        return (p.x - campaign.partyPosition.x).abs() <= 2 && (p.y - campaign.partyPosition.y).abs() <= 2;
      }).toList();
      if (candidates.isEmpty) continue;
      final to = candidates[rng.nextInt(candidates.length)];
      member.position = to;
      visited.add('${to.x},${to.y}');
      campaign.visitedTiles.add('${to.x},${to.y}');
    }
  }

  /// Every current party member's own portrait+name, in party order — every
  /// hero and recruited companion gets their own token clustered on the
  /// map, not just a single stand-in for "the party."
  List<PartyMemberVisual> _partyVisuals(CampaignState? campaign, List<Character> chars) {
    if (campaign == null || campaign.party.isEmpty) return [];
    final charsById = {for (final c in chars) c.id: c};
    return [
      for (final member in campaign.party)
        if (charsById[member.characterId] != null)
          PartyMemberVisual(
            name: member.name,
            portraitAsset: 'assets/avatar/portraits/${charsById[member.characterId]!.race.name}.png',
            pos: member.position != null ? m.Point(member.position!.x, member.position!.y) : null,
          ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _adHocSeed = Random().nextInt(1 << 30);
    if (widget.sessionId != null) {
      _initMultiplayer();
    } else {
      // Load persisted campaign if any (solo play only — a multiplayer
      // session's state comes from the host/Firestore instead).
      Future.microtask(() => ref.read(campaignProvider.notifier).loadPersisted());
    }
  }

  Future<void> _initMultiplayer() async {
    final sessionId = widget.sessionId;
    if (sessionId == null) return;
    final host = await SessionRepository.instance.isHost(sessionId);
    if (!mounted) return;
    setState(() => _isMultiplayerHost = host);
    if (host) {
      // Ensure there's a real CampaignState to narrate against and push —
      // hosting a lobby only creates the Firestore session doc, it doesn't
      // start a local campaign by itself.
      if (ref.read(campaignProvider) == null) {
        final info = await SessionRepository.instance.getSession(sessionId);
        final seedJson = info.campaignSeedJson;
        final seed = seedJson != null ? CampaignSeed.fromJson(seedJson) : CampaignSeed.presets.first;
        final chars = ref.read(savedCharactersProvider);
        ref.read(campaignProvider.notifier).startNew(seed, chars);
      }
      final campaign = ref.read(campaignProvider);
      if (campaign != null) SessionRepository.instance.pushState(sessionId, campaign);
      _actionsSub = SessionRepository.instance.watchPendingActions(sessionId).listen(_handlePendingActions);
    } else {
      _stateSub = SessionRepository.instance.watchState(sessionId).listen(_handleSyncedState);
    }
  }

  void _handleSyncedState(Map<String, dynamic>? json) {
    if (json == null || !mounted) return;
    final cs = CampaignState.fromJson(json);
    if (cs.recentTurns.length > _renderedTurnCount) {
      final newTurns = cs.recentTurns.skip(_renderedTurnCount).toList();
      for (final t in newTurns) {
        chat.add({'role': 'player', 'text': t.playerInput});
        chat.add({'role': 'dm', 'text': t.dmResponse});
      }
      _renderedTurnCount = cs.recentTurns.length;
      _isGenerating = false;
      // Only the newest turn — speaking a whole catch-up backlog on rejoin
      // would queue up several turns of narration back-to-back.
      _maybeSpeak(newTurns.last.dmResponse);
    }
    ref.read(campaignProvider.notifier).load(cs);
    setState(() {});
  }

  Future<void> _handlePendingActions(QuerySnapshot<Map<String, dynamic>> snap) async {
    final sessionId = widget.sessionId;
    if (sessionId == null) return;
    for (final doc in snap.docs) {
      final text = (doc.data()['actionText'] as String?)?.trim() ?? '';
      if (text.isNotEmpty) await _send(text, fromRemote: true);
      await SessionRepository.instance.markActionProcessed(sessionId, doc.id);
    }
  }

  /// A message starting with "@Name" is addressed to that one party member
  /// specifically — matched against the party's own real names (longest
  /// first, so "@Old Sella" isn't mis-matched by a shorter name that's a
  /// prefix of it). Returns the mention-stripped text the model should
  /// actually respond to, plus who (if anyone) it's addressed to.
  ({String? addressedTo, String text}) _parseMention(String raw, CampaignState? campaign) {
    if (campaign == null || !raw.startsWith('@')) return (addressedTo: null, text: raw);
    final names = campaign.party.map((m) => m.name).toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final name in names) {
      final mention = '@$name';
      if (raw.toLowerCase().startsWith(mention.toLowerCase())) {
        final rest = raw.substring(mention.length).trim();
        return (addressedTo: name, text: rest.isEmpty ? 'Yes? What do you need?' : rest);
      }
    }
    return (addressedTo: null, text: raw);
  }

  /// Tapping a party member's avatar addresses them directly — inserts
  /// "@Name " into the input and focuses it, ready to type. An empty box
  /// (or the Quick Actions/no @) always speaks to the whole party instead.
  void _mentionMember(String name) {
    _inputController.text = '@$name ';
    _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
    _inputFocus.requestFocus();
    AudioService.instance.playTap();
  }

  void _maybeSpeak(String text) {
    if (text.trim().isEmpty) return;
    if (ref.read(settingsProvider).voiceNarrationEnabled) TtsService.instance.speak(text);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    _mapController.dispose();
    _stateSub?.cancel();
    _actionsSub?.cancel();
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _send(String text, {bool fromRemote = false}) async {
    if (text.trim().isEmpty) return;
    if (_isGenerating && !fromRemote) return;
    AudioService.instance.playSend();
    final campaign = ref.read(campaignProvider);

    // Guest in a multiplayer session: never run the model locally — submit
    // the action to the host's device and wait for the synced state to
    // reflect it (see _handleSyncedState).
    if (widget.sessionId != null && _isMultiplayerHost != true && !fromRemote) {
      setState(() {
        _isGenerating = true;
        _streamingText = '';
      });
      _inputController.clear();
      try {
        await SessionRepository.instance.submitAction(widget.sessionId!, text);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          chat.add({'role': 'dm', 'text': 'Could not reach the host — check your connection and try again.'});
          _isGenerating = false;
        });
      }
      return;
    }

    setState(() {
      chat.add({'role': 'player', 'text': text});
      _isGenerating = true;
      _streamingText = '';
    });
    if (!fromRemote) _inputController.clear();

    try {
      if (campaign == null) {
        // No active campaign (exploring an ad-hoc dungeon) — still goes through the
        // real inference service, just without persisted CampaignState/action-tools.
        final model = ref.read(modelServiceProvider);
        final prompt =
            'You are a Dungeon Master narrating a solo dungeon crawl. The room: ${_dungeon.describeRoom(0)}. '
            'Player says: "$text". Narrate what happens next in 1-3 sentences.';
        await for (final chunk in model.generate(prompt)) {
          if (!mounted) return;
          setState(() => _streamingText += chunk);
        }
        final narration = _streamingText.trim();
        setState(() {
          chat.add({'role': 'dm', 'text': narration});
          _isGenerating = false;
          _streamingText = '';
        });
        _maybeSpeak(narration);
      } else {
        final engine = ref.read(dmEngineProvider);
        final mention = _parseMention(text, campaign);
        final result = await engine.takeTurn(
          playerInput: mention.text,
          state: campaign,
          addressedTo: mention.addressedTo,
          onToken: (chunk) {
            if (!mounted) return;
            setState(() => _streamingText += chunk);
          },
        );
        if (result.hadRoll) AudioService.instance.playDiceRoll();
        _switchEnvironmentIfNeeded(campaign, result.narration);
        _wanderCompanions(campaign);
        setState(() {
          chat.add({'role': 'dm', 'text': result.narration, 'roll': _rollBadge(result)});
          _isGenerating = false;
          _streamingText = '';
          ref.read(campaignProvider.notifier).load(campaign); // refresh UI
        });
        _maybeSpeak(result.narration);
        if (widget.sessionId != null && _isMultiplayerHost == true) {
          SessionRepository.instance.pushState(widget.sessionId!, campaign);
        }
      }
    } catch (e) {
      AudioService.instance.playError();
      if (!mounted) return;
      setState(() {
        chat.add({'role': 'dm', 'text': 'The Dungeon Master falls silent for a moment... (${_friendlyError(e)})'});
        _isGenerating = false;
        _streamingText = '';
      });
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('MODEL_NOT_DOWNLOADED')) return 'AI model not downloaded yet — visit Settings to download it.';
    if (s.contains('TIMEOUT')) return 'the model took too long to respond';
    return 'a technical hiccup';
  }

  String _rollBadge(DmTurnResult result) {
    if (result.attack != null) {
      final a = result.attack!;
      final crit = a.critical ? ' CRIT!' : '';
      final dmg = a.hit && a.damage != null ? ' • ${a.damage!.total} dmg' : '';
      return '${a.hit ? "HIT" : "MISS"} (d20:${a.roll}+${a.modifier}=${a.total} vs AC ${a.targetAc})$crit$dmg';
    }
    if (result.check != null) {
      final c = result.check!;
      final flourish = c.critical ? ' NAT 20!' : c.fumble ? ' NAT 1!' : '';
      return '${c.success ? "SUCCESS" : "FAIL"} (${c.ability} d20:${c.roll}+${c.modifier}=${c.total} vs DC ${c.dc})$flourish';
    }
    if (result.dice != null) return '${result.dice!.total}';
    return '';
  }

  void _move(int dx, int dy) {
    final nx = playerPos.x + dx;
    final ny = playerPos.y + dy;
    if (nx < 0 || ny < 0 || nx >= _dungeon.width || ny >= _dungeon.height) return;
    if (_dungeon.tileAt(nx, ny) == m.TileType.wall || _dungeon.tileAt(nx, ny) == m.TileType.water) return;
    setState(() {
      playerPos = m.Point(nx, ny);
      visited.add('$nx,$ny');
    });
    // NOTE: was previously `moveTo(m.Point(nx, ny) as dynamic)` — m.Point is
    // the *map tile* Point (tile_types.dart), a completely different class
    // from the domain Point CampaignState actually expects; the `dynamic`
    // cast hid the mismatch at compile time. Passing the right type directly.
    ref.read(campaignProvider.notifier).moveTo(Point(nx, ny));
    _recenterOnPlayer(); // keep the camera following the party on the iso map
    // auto describe
    _send('I move to the next area.');
  }

  void _regenerate() {
    final campaign = ref.read(campaignProvider);
    final newSeed = Random().nextInt(1 << 30);
    final newDungeon = DungeonGenerator().generate(seed: newSeed, width: 18, height: 18);
    setState(() {
      _adHocSeed = newSeed;
      _seed = newSeed;
      _dungeon = newDungeon;
      playerPos = m.Point(newDungeon.entryPoint.x, newDungeon.entryPoint.y);
      visited = {'${playerPos.x},${playerPos.y}'};
      _mapInitialized = true;
      _mapCentered = false;
      chat.clear();
    });
    if (campaign != null) {
      campaign.mapSeed = newSeed;
      campaign.partyPosition = Point(playerPos.x, playerPos.y);
      campaign.visitedTiles = Set<String>.from(visited);
      // "New Dungeon" narratively means moving on to a brand-new area —
      // advances the remembered dungeon depth just like a real in-story
      // descent would, so this new map is the one reused if they come back.
      campaign.mapEnvironment = 'dungeon';
      final nextDepth = (campaign.worldFlags['dungeonDepth'] as int? ?? 0) + 1;
      campaign.worldFlags['dungeonDepth'] = nextDepth;
      campaign.locationSeeds['dungeon_$nextDepth'] = newSeed;
      ref.read(campaignProvider.notifier).load(campaign);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = ref.watch(campaignProvider);
    final chars = ref.watch(savedCharactersProvider);
    _ensureMapForCampaign(campaign);
    // Collapse the map viewport while the keyboard is up — the map, quick
    // actions row, and input bar are all fixed-height siblings in the body
    // Column, so with the keyboard eating screen height at full map size
    // their combined height can exceed what's left and overflow the bottom.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final mapHeight = keyboardOpen ? 120.0 : 280.0;

    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(campaign?.seed.title.toUpperCase() ?? 'ADVENTURE', style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.casino_rounded, size: 18), onPressed: _regenerate),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 18), onPressed: _regenerate, tooltip: 'New Dungeon'),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18),
            color: ArcaneTheme.surface,
            onSelected: (v) {
              if (v == 'new_campaign' && chars.isNotEmpty) {
                final seed = CampaignSeed.presets.first;
                ref.read(campaignProvider.notifier).startNew(seed, chars);
                setState(() => chat.clear());
              }
            },
            itemBuilder: (c) => [
              PopupMenuItem(value: 'new_campaign', child: Text('New Campaign', style: GoogleFonts.ibmPlexSans(color: Colors.white))),
              PopupMenuItem(value: 'seed', child: Text('Seed: $_seed', style: GoogleFonts.ibmPlexSans(color: ArcaneTheme.textSecondary, fontSize: 12))),
            ],
          ),
        ],
      ),
      body: Column(children: [
        // Map viewport — matches Stitch Main Gameplay Screen dungeon tile look
        Container(
          height: mapHeight,
          width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFF0B0A12), border: Border(bottom: BorderSide(color: ArcaneTheme.border))),
          child: Stack(children: [
            // Isometric grid — real pinch-to-zoom/pan via InteractiveViewer, plus
            // the +/-/locate buttons below drive the same TransformationController.
            LayoutBuilder(builder: (context, constraints) {
              _mapViewportSize = constraints.biggest;
              if (!_mapCentered && !_recenterScheduled) {
                _recenterScheduled = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _recenterScheduled = false;
                  if (mounted) _recenterOnPlayer();
                });
              }
              return InteractiveViewer(
                transformationController: _mapController,
                minScale: _minZoom,
                maxScale: _maxZoom,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(200),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IsoMapView(
                    dungeon: _dungeon,
                    playerPos: playerPos,
                    visited: visited,
                    partyMembers: _partyVisuals(campaign, chars),
                    environment: campaign?.mapEnvironment ?? 'dungeon',
                    npcs: _npcs,
                    props: _props,
                    onNpcTap: (npc) => _send('I approach and talk to ${npc.name} the ${npc.role.toLowerCase()}.'),
                  ),
                ),
              );
            }),
            // Controls overlay
            Positioned(
              right: 8,
              top: 8,
              child: Column(children: [
                _MapBtn(icon: Icons.add_rounded, onTap: () => _zoomBy(1.4)),
                const SizedBox(height: 6),
                _MapBtn(icon: Icons.remove_rounded, onTap: () => _zoomBy(1 / 1.4)),
                const SizedBox(height: 6),
                _MapBtn(icon: Icons.my_location_rounded, onTap: _recenterOnPlayer),
              ]),
            ),
            // D-pad
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.08))),
                child: Column(children: [
                  _DpadBtn(icon: Icons.keyboard_arrow_up_rounded, onTap: () => _move(0, -1)),
                  Row(children: [
                    _DpadBtn(icon: Icons.keyboard_arrow_left_rounded, onTap: () => _move(-1, 0)),
                    const SizedBox(width: 30, height: 30),
                    _DpadBtn(icon: Icons.keyboard_arrow_right_rounded, onTap: () => _move(1, 0)),
                  ]),
                  _DpadBtn(icon: Icons.keyboard_arrow_down_rounded, onTap: () => _move(0, 1)),
                ]),
              ),
            ),
            // Room label
            Positioned(
              bottom: 8,
              right: 56,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(6)),
                child: Text('Seed $_seed • ${_dungeon.rooms.length} rooms • Tap arrows to move', style: GoogleFonts.ibmPlexSans(fontSize: 10, color: Colors.white70)),
              ),
            ),
          ]),
        ),

        // Party strip — every hero and recruited AI companion currently
        // adventuring with you, visible at a glance (distinct from the
        // Party *tab*, which is about multiplayer hosting/joining).
        if (campaign != null && campaign.party.isNotEmpty)
          Container(
            height: 72,
            decoration: const BoxDecoration(color: ArcaneTheme.surface, border: Border(bottom: BorderSide(color: ArcaneTheme.border))),
            child: Builder(builder: (context) {
              final visuals = _partyVisuals(campaign, chars);
              return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: campaign.party.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (c, i) {
                final m = campaign.party[i];
                final asset = visuals.length > i ? visuals[i].portraitAsset : null;
                final isLead = i == 0;
                return PressableScale(
                  onTap: isLead ? null : () => _mentionMember(m.name),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: isLead ? 17 : 14,
                    backgroundColor: (isLead ? ArcaneTheme.primary : ArcaneTheme.secondary).withOpacity(0.18),
                    backgroundImage: asset != null ? AssetImage(asset) : null,
                    child: asset == null ? Icon(Icons.person_rounded, size: isLead ? 16 : 13, color: isLead ? ArcaneTheme.primary : ArcaneTheme.secondary) : null,
                  ),
                  const SizedBox(height: 2),
                  Text(isLead ? '${m.name} (You)' : m.name, style: GoogleFonts.ibmPlexSans(fontSize: 9, fontWeight: FontWeight.w700, color: ArcaneTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                );
              },
              );
            }),
          ),

        // Narration / Chat
        Expanded(
          child: Container(
            color: ArcaneTheme.background,
            child: chat.isEmpty && _streamingText.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: ArcaneTheme.arcane.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.auto_stories_rounded, color: ArcaneTheme.arcane, size: 28)),
                        const SizedBox(height: 14),
                        Text(campaign == null ? 'The dungeon awaits your first words...' : campaign.currentSceneDescription, textAlign: TextAlign.center, style: GoogleFonts.spectral(fontSize: 15, fontStyle: FontStyle.italic, color: ArcaneTheme.textSecondary, height: 1.5)),
                        const SizedBox(height: 10),
                        Text('Try: "I inspect the altar" or "I attack the shadow"', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
                      ]),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    children: [
                      if (campaign != null) _SceneBlock(text: campaign.currentSceneDescription),
                      ...chat.map((m) {
                        final isPlayer = m['role'] == 'player';
                        final roll = m['roll'];
                        final isCrit = roll != null && (roll.contains('CRIT') || roll.contains('NAT 20'));
                        return FadeSlideIn(
                          child: isPlayer
                              ? _ActionLine(text: m['text']!)
                              : _SceneBlock(
                                  text: m['text']!,
                                  trailing: (roll != null && roll.isNotEmpty)
                                      ? RollBadgePop(
                                          critical: isCrit,
                                          child: Container(
                                            margin: const EdgeInsets.only(top: 10),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (isCrit ? ArcaneTheme.tertiary : ArcaneTheme.secondary).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: isCrit ? Border.all(color: ArcaneTheme.tertiary.withOpacity(0.6)) : null,
                                            ),
                                            child: Text('🎲 $roll', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: isCrit ? ArcaneTheme.tertiary : ArcaneTheme.secondary)),
                                          ),
                                        )
                                      : null,
                                ),
                        );
                      }),
                      if (_isGenerating)
                        FadeSlideIn(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: ArcaneTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(4),
                              border: const Border(left: BorderSide(color: ArcaneTheme.arcane, width: 3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              TypingDots(color: ArcaneTheme.arcane),
                              const SizedBox(width: 10),
                              Flexible(child: Text(_streamingText.isEmpty ? 'The Dungeon Master is weaving your fate...' : _streamingText, style: GoogleFonts.spectral(fontSize: 14, fontStyle: FontStyle.italic, color: ArcaneTheme.textSecondary, height: 1.5))),
                            ]),
                          ),
                        ),
                    ],
                  ),
          ),
        ),

        // Quick actions — match Stitch: Attack, Talk, Inspect, Roll Die
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _QuickAction(icon: Icons.flash_on_rounded, label: 'Attack', color: ArcaneTheme.tertiary, onTap: () => _send('I attack the nearest foe!')),
              _QuickAction(icon: Icons.chat_bubble_rounded, label: 'Talk', color: ArcaneTheme.primary, onTap: () => _send('I try to talk to whoever is here.')),
              _QuickAction(icon: Icons.search_rounded, label: 'Inspect', color: ArcaneTheme.secondary, onTap: () => _send('I inspect the room carefully.')),
              _QuickAction(icon: Icons.casino_rounded, label: 'Roll Die', color: ArcaneTheme.primary, onTap: () => _send('I roll for perception.')),
            ]),
          ),
        ),

        // Input bar — flush with keyboard, no gap
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 8 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: ArcaneTheme.surface, border: Border(top: BorderSide(color: ArcaneTheme.border))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(hintText: 'Speak to the party, or tap someone to address them...', filled: true, fillColor: ArcaneTheme.surfaceElevated, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                onSubmitted: _send,
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            PressableScale(
              onTap: () => _send(_inputController.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: ArcaneTheme.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: ArcaneTheme.primary.withOpacity(0.3), blurRadius: 8)]),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _isGenerating
                      ? const Padding(key: ValueKey('spinner'), padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, key: ValueKey('send'), color: Colors.white, size: 18),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// DM narration rendered as a page from the story rather than a chat bubble —
/// a quoted illuminated block with a gold spine, serif italics, no avatar.
class _SceneBlock extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _SceneBlock({required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(ArcaneTheme.surfaceCard, ArcaneTheme.secondary, 0.06)!, ArcaneTheme.surfaceCard]),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: ArcaneTheme.secondary.withOpacity(0.55), width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: GoogleFonts.spectral(fontSize: 14.5, fontStyle: FontStyle.italic, color: ArcaneTheme.textPrimary, height: 1.55)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// A player's typed action — a script-style cue rather than a bubble: right
/// aligned, ember-colored, prefixed by a chevron instead of a filled shape.
class _ActionLine extends StatelessWidget {
  final String text;
  const _ActionLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 32),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.chevron_left_rounded, size: 18, color: ArcaneTheme.primary.withOpacity(0.8)),
        const SizedBox(width: 2),
        Flexible(child: Text(text, textAlign: TextAlign.right, style: GoogleFonts.ibmPlexSans(fontSize: 13.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: ArcaneTheme.primary, height: 1.4))),
      ]),
    );
  }
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.12))), child: Icon(icon, size: 16, color: Colors.white)),
    );
  }
}

class _DpadBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DpadBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressableScale(onTap: onTap, downScale: 0.85, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: Colors.white70)));
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
          child: Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}
