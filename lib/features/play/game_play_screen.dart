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
import '../../domain/ability_scores.dart';
import '../../domain/campaign_seed.dart';
import '../../domain/campaign_state.dart';
import '../../domain/character.dart';
import '../../domain/dm_turn_engine.dart';
import '../../domain/pet_companion.dart';
import '../../services/audio_service.dart';
import '../../services/session_repository.dart';
import '../../services/tts_service.dart';
import '../../services/tv_cast_service.dart';
import '../../services/voice_transcription_service.dart';
import '../../services/smart_ai_service.dart';
import '../../widgets/fx.dart';
import '../../widgets/campaign_journal_sheet.dart';
import '../../widgets/inventory_sheet.dart';
import '../../widgets/tactical_combat_sheet.dart';
import '../../widgets/npc_interaction_sheet.dart';
import '../../widgets/tv_cast_sheet.dart';
import 'dungeon_populator.dart';
import 'iso_map_view.dart';
import 'tavern_populator.dart';

class GamePlayScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  const GamePlayScreen({super.key, this.sessionId});
  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  final TextEditingController _inputController = TextEditingController();
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
  List<MapAnimal> _animals = [];
  List<MapProp> _props = [];
  Set<String> visited = {};
  m.Point playerPos = const m.Point(5, 5);
  m.Point? _targetWaypoint;
  List<m.Point>? _activePath;
  final Set<String> _openedDoors = {};
  final Set<String> _traps = {};
  final Set<String> _revealedTraps = {};
  final Set<int> _discoveredRoomIds = {};
  bool _isTraversing = false;
  List<Map<String, String>> chat = [];

  Set<String> get _solidPropPositions =>
      _props.where((p) => p.isSolid).map((p) => '${p.pos.x},${p.pos.y}').toSet();
  // Guards a one-time rebuild of [chat] from the persisted campaign's
  // recentTurns — without this, leaving and returning to this screen
  // recreates a fresh State object with an empty `chat` list, even though
  // the actual campaign (party, map, quests, HP, inventory) is untouched.
  bool _chatHydrated = false;

  // Multiplayer: null until resolved (solo, or resolving host/guest role).
  // Host runs the real DM engine for both its own input and guests' submitted
  // actions; a guest never touches the model — it submits via Firestore and
  // renders whatever the host syncs back.
  bool? _isMultiplayerHost;
  StreamSubscription<Map<String, dynamic>?>? _stateSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _actionsSub;
  int _renderedTurnCount = 0;
  bool _isTvCompanionMode = false;
  bool _isVoiceListening = false;
  String _voiceStatusText = '';
  double _voiceSoundLevel = 0.0;
  StreamSubscription<int>? _tvClientCountSub;
  bool _is3dPerspective = false;
  List<SmartSuggestion> _smartSuggestions = [];
  bool _isLoadingSuggestions = false;
  final Map<String, String> _companionSpeechBubbles = {};
  Timer? _companionSpeechTimer;
  Timer? _companionAutonomyTimer;
  bool _showingSidequestsHud = false;

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

  void _recenterOnTile(m.Point tile) {
    const outerPadding = 8.0;
    final originX = _dungeon.height * IsoMapView.tileW / 2;
    const originY = IsoMapView.tileH / 2;
    final tileScreen = Offset(
      outerPadding + originX + (tile.x - tile.y) * IsoMapView.tileW / 2 + IsoMapView.tileW / 2,
      outerPadding + originY + (tile.x + tile.y) * IsoMapView.tileH / 2 + IsoMapView.tileH / 2,
    );
    final viewportCenter = Offset(_mapViewportSize.width / 2, _mapViewportSize.height / 2);
    final matrix = Matrix4.identity()
      ..translate(viewportCenter.dx, viewportCenter.dy)
      ..scale(_baseFitScale * 1.2)
      ..translate(-tileScreen.dx, -tileScreen.dy);
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
    if (campaign == null && widget.sessionId != null) return;
    final targetSeed = campaign?.mapSeed ?? _adHocSeed;
    if (_mapInitialized && _seed == targetSeed) {
      if (campaign != null) {
        _openedDoors.addAll(campaign.openedDoors);
        _npcs.removeWhere((n) => campaign.defeatedEnemies.contains(n.id));
      }
      return;
    }
    _seed = targetSeed;
    _dungeon = DungeonGenerator().generate(seed: _seed, width: 34, height: 34);
    if (campaign != null) {
      playerPos = m.Point(campaign.partyPosition.x, campaign.partyPosition.y);
      visited = campaign.visitedTiles.isNotEmpty ? Set<String>.from(campaign.visitedTiles) : {'${playerPos.x},${playerPos.y}'};
      _openedDoors.clear();
      _openedDoors.addAll(campaign.openedDoors);
    } else {
      playerPos = m.Point(_dungeon.entryPoint.x, _dungeon.entryPoint.y);
      visited = {'${playerPos.x},${playerPos.y}'};
      _openedDoors.clear();
    }
    if ((campaign?.mapEnvironment ?? 'dungeon') == 'tavern') {
      _npcs = generateTavernNpcs(_dungeon);
      _props = generateTavernProps(_dungeon, _npcs);
      _animals = generateTavernAnimals(_dungeon, excluding: {
        '${playerPos.x},${playerPos.y}',
        for (final p in _props) '${p.pos.x},${p.pos.y}',
        for (final n in _npcs) '${n.pos.x},${n.pos.y}',
      });
    } else {
      _props = generateDungeonProps(_dungeon);
      final allEnemies = generateDungeonEnemies(_dungeon, excluding: {
        for (final p in _props) '${p.pos.x},${p.pos.y}',
      });
      final defeated = campaign?.defeatedEnemies ?? const <String>{};
      final roamingNpcs = generateDungeonRoamingNpcs(_dungeon, excluding: {
        for (final p in _props) '${p.pos.x},${p.pos.y}',
        for (final e in allEnemies) '${e.pos.x},${e.pos.y}',
      });
      final partyNames = campaign?.party.map((p) => p.name).toSet() ?? {};
      _npcs = [
        ...allEnemies.where((n) => !defeated.contains(n.id)),
        ...roamingNpcs.where((n) => !partyNames.contains(n.name)),
      ];
      _animals = generateDungeonAnimals(_dungeon, excluding: {
        '${playerPos.x},${playerPos.y}',
        for (final p in _props) '${p.pos.x},${p.pos.y}',
        for (final n in _npcs) '${n.pos.x},${n.pos.y}',
      });
      for (final e in allEnemies) {
        if (defeated.contains(e.id)) {
          _props.add(MapProp(pos: e.pos, asset: 'assets/tiles/prop_bones.png', isSolid: false));
        }
      }
      _traps.clear();
      _revealedTraps.clear();
      final trapRng = Random(_seed ^ 0x54524150); // Deterministic "TRAP"
      final candidates = <String>[];
      for (var y = 2; y < _dungeon.height - 2; y++) {
        for (var x = 2; x < _dungeon.width - 2; x++) {
          if (_dungeon.tileAt(x, y) == m.TileType.floor &&
              !(x == playerPos.x && y == playerPos.y) &&
              !(x == _dungeon.entryPoint.x && y == _dungeon.entryPoint.y)) {
            candidates.add('$x,$y');
          }
        }
      }
      candidates.shuffle(trapRng);
      for (final t in candidates.take(4)) {
        _traps.add(t);
      }
    }

    // Initialize discovered rooms
    _discoveredRoomIds.clear();
    for (final r in _dungeon.rooms) {
      if (r.contains(playerPos) ||
          visited.any((v) {
            final p = v.split(',');
            final vx = int.tryParse(p[0]) ?? -1;
            final vy = int.tryParse(p[1]) ?? -1;
            return r.contains(m.Point(vx, vy));
          })) {
        _discoveredRoomIds.add(r.id);
      }
    }

    // Initialize companion positions on adjacent walkable tiles if unassigned
    if (campaign != null && campaign.party.length > 1) {
      final adjacent = [
        m.Point(playerPos.x - 1, playerPos.y),
        m.Point(playerPos.x + 1, playerPos.y),
        m.Point(playerPos.x, playerPos.y - 1),
        m.Point(playerPos.x, playerPos.y + 1),
      ].where((p) => _isWalkableTile(p.x, p.y)).toList();

      for (var i = 1; i < campaign.party.length; i++) {
        final member = campaign.party[i];
        if (member.position == null && i - 1 < adjacent.length) {
          member.position = Point(adjacent[i - 1].x, adjacent[i - 1].y);
          visited.add('${adjacent[i - 1].x},${adjacent[i - 1].y}');
        }
      }
    }

    _mapInitialized = true;
    _mapCentered = false;
  }

  /// Rebuilds the on-screen transcript from the persisted campaign the
  /// first time one is available on a fresh State object (multiplayer
  /// guests already rebuild their transcript from synced state in
  /// _handleSyncedState, so this only applies to solo/host play). Turns
  /// older than the DM engine's summarization window (see
  /// DmTurnEngine._maybeSummarize) are already folded into runningSummary
  /// rather than kept verbatim — that's an existing context-window
  /// tradeoff, not something this restores further back than.
  void _ensureChatForCampaign(CampaignState? campaign) {
    if (_chatHydrated || campaign == null || widget.sessionId != null) return;
    _chatHydrated = true;
    if (chat.isEmpty) {
      for (final t in campaign.recentTurns) {
        chat.add({'role': 'player', 'text': t.playerInput});
        chat.add({'role': 'dm', 'text': t.dmResponse});
      }
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

  /// Companions are meant to be *mostly* autonomous, not just reactive to
  /// the player — after most turns, one random companion (never the lead)
  /// gets a real, separate short generation focused entirely on their own
  /// persona, acting or speaking on their own initiative with no player
  /// input driving it. Renders as its own DM-narration entry in the log.
  Future<void> _maybeCompanionBeat(CampaignState campaign, DmTurnEngine engine, {bool skip = false}) async {
    if (skip || campaign.party.length <= 1) return;
    if (Random().nextDouble() > 0.55) return;
    final companions = campaign.party.skip(1).toList();
    final companion = companions[Random().nextInt(companions.length)];
    try {
      final beat = await engine.companionBeat(state: campaign, companion: companion);
      if (beat == null || beat.narration.isEmpty || !mounted) return;
      setState(() {
        chat.add({'role': 'dm', 'text': beat.narration, 'roll': _rollBadge(beat)});
        ref.read(campaignProvider.notifier).load(campaign);
      });
      _maybeSpeak(beat.narration);
      if (widget.sessionId != null && _isMultiplayerHost == true) {
        SessionRepository.instance.pushState(widget.sessionId!, campaign);
      }
    } catch (_) {
      // Flavor, not critical path — a failed beat just means a quieter turn.
    }
  }

  Future<void> _refreshSmartSuggestions() async {
    if (!mounted || _isLoadingSuggestions) return;
    _isLoadingSuggestions = true;
    try {
      final campaign = ref.read(campaignProvider);
      final chars = ref.read(savedCharactersProvider);
      final pet = _getActivePet(campaign, chars);
      final suggestions = await SmartAiService.instance.getContextualSuggestions(
        chatHistory: chat,
        campaign: campaign,
        pet: pet,
      );
      if (mounted) {
        setState(() {
          _smartSuggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) _isLoadingSuggestions = false;
    }
  }

  String _portraitForMember(PartyMemberStatus member, Map<String, Character> charsById) {
    final c = charsById[member.characterId];
    if (c != null) return 'assets/avatar/portraits/${c.race.name}.png';
    final lower = member.raceLabel.toLowerCase();
    if (lower.contains('dwarf')) return 'assets/avatar/portraits/dwarf.png';
    if (lower.contains('elf')) return 'assets/avatar/portraits/elf.png';
    if (lower.contains('dragon')) return 'assets/avatar/portraits/dragonborn.png';
    if (lower.contains('half') || lower.contains('gnome')) return 'assets/avatar/portraits/halfling.png';
    if (lower.contains('orc')) return 'assets/avatar/portraits/orc.png';
    if (lower.contains('tief')) return 'assets/avatar/portraits/tiefling.png';
    return 'assets/avatar/portraits/human.png';
  }

  /// Every current party member's own portrait+name, in party order — every
  /// hero and recruited companion gets their own token clustered on the
  /// map, not just a single stand-in for "the party."
  List<PartyMemberVisual> _partyVisuals(CampaignState? campaign, List<Character> chars) {
    if (campaign == null || campaign.party.isEmpty) return [];
    final charsById = {for (final c in chars) c.id: c};
    return [
      for (final member in campaign.party)
        PartyMemberVisual(
          name: member.name,
          portraitAsset: _portraitForMember(member, charsById),
          pos: member.position != null ? m.Point(member.position!.x, member.position!.y) : null,
          speechBubble: _companionSpeechBubbles[member.characterId],
          onTap: () => _showCompanionInteractionSheet(member),
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _adHocSeed = Random().nextInt(1 << 30);
    SmartAiService.instance.initialize();
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _refreshSmartSuggestions();
    });
    _tvClientCountSub = TvCastService.instance.clientCountStream.listen((count) {
      if (count > 0) _broadcastTvState();
      if (mounted) setState(() {});
    });
    _companionAutonomyTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _runCompanionAutonomousBehavior();
    });
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
    if (campaign == null) return (addressedTo: null, text: raw);
    final trimmed = raw.trim();

    // 1. Direct @Mention prefix: "@Thorin attack the skeleton"
    if (trimmed.startsWith('@')) {
      final names = campaign.party.map((m) => m.name).toList()..sort((a, b) => b.length.compareTo(a.length));
      for (final name in names) {
        final mention = '@$name';
        if (trimmed.toLowerCase().startsWith(mention.toLowerCase())) {
          final rest = trimmed.substring(mention.length).trim();
          return (addressedTo: name, text: rest.isEmpty ? 'Yes? What do you need?' : rest);
        }
      }
    }

    // 2. Natural language companion command: "Thorin, smash the door" or "Tell Elora to heal me"
    final companions = campaign.party.skip(1);
    for (final companion in companions) {
      final cName = companion.name.toLowerCase();
      final lower = trimmed.toLowerCase();

      // "Thorin, ...", "Thorin: ..."
      if (lower.startsWith('$cName,') || lower.startsWith('$cName:')) {
        final rest = trimmed.substring(cName.length + 1).trim();
        return (addressedTo: companion.name, text: rest.isEmpty ? 'At your command.' : rest);
      }

      // "Tell Thorin to ..." or "Ask Thorin to ..."
      for (final prefix in ['tell $cName to ', 'ask $cName to ', 'order $cName to ', 'have $cName ']) {
        if (lower.startsWith(prefix)) {
          final rest = trimmed.substring(prefix.length).trim();
          return (addressedTo: companion.name, text: rest);
        }
      }

      // Starts with companion name: "Thorin attack the goblin"
      if (lower.startsWith('$cName ')) {
        final rest = trimmed.substring(cName.length + 1).trim();
        return (addressedTo: companion.name, text: rest);
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
    _tvClientCountSub?.cancel();
    _companionSpeechTimer?.cancel();
    _companionAutonomyTimer?.cancel();
    VoiceTranscriptionService.instance.cancelListening();
    _inputController.dispose();
    _inputFocus.dispose();
    _mapController.dispose();
    _stateSub?.cancel();
    _actionsSub?.cancel();
    TtsService.instance.stop();
    SmartAiService.instance.dispose();
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
    TvCastService.instance.broadcastNarration('Player', text);
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
        TvCastService.instance.broadcastNarration('Dungeon Master', narration);
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
        if (result.hadRoll) {
          AudioService.instance.playDiceRoll();
          if (result.attack != null) {
            final a = result.attack!;
            TvCastService.instance.broadcastDiceRoll(
              roller: 'Player',
              reason: a.hit ? 'Attack (HIT)' : 'Attack (MISS)',
              d20: a.roll,
              modifier: a.modifier,
              total: a.total,
            );
          } else if (result.check != null) {
            final c = result.check!;
            TvCastService.instance.broadcastDiceRoll(
              roller: 'Player',
              reason: '${c.ability} Check',
              d20: c.roll,
              modifier: c.modifier,
              total: c.total,
            );
          }
        }
        _wanderCompanions(campaign);
        setState(() {
          chat.add({'role': 'dm', 'text': result.narration, 'roll': _rollBadge(result)});
          _isGenerating = false;
          _streamingText = '';
          ref.read(campaignProvider.notifier).load(campaign); // refresh UI
        });
        _maybeSpeak(result.narration);
        TvCastService.instance.broadcastNarration('Dungeon Master', result.narration);
        _broadcastTvState();
        if (widget.sessionId != null && _isMultiplayerHost == true) {
          SessionRepository.instance.pushState(widget.sessionId!, campaign);
        }
        // A one-on-one exchange with a specific companion (mention.addressedTo)
        // stays theirs alone — no unrelated beat butting in right after.
        await _maybeCompanionBeat(campaign, engine, skip: mention.addressedTo != null);
      }
    } catch (_) {
      if (!mounted) return;
      const fallback = 'Torchlight flickers against the ancient stones as you steady your grip on your weapon and advance.';
      setState(() {
        chat.add({
          'role': 'dm',
          'text': fallback,
        });
        _isGenerating = false;
        _streamingText = '';
      });
      TvCastService.instance.broadcastNarration('Dungeon Master', fallback);
    }
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

  PetCompanion? _getActivePet(CampaignState? campaign, List<Character> chars) {
    if (campaign == null || campaign.party.isEmpty) return null;
    for (final member in campaign.party) {
      final ch = chars.where((c) => c.id == member.characterId).firstOrNull;
      if (ch != null && ch.avatar.pet != 'none') {
        return PetCompanion.fromId(ch.avatar.pet);
      }
    }
    return null;
  }

  bool _isWalkableTile(int x, int y) {
    if (x < 0 || y < 0 || x >= _dungeon.width || y >= _dungeon.height) return false;
    final tile = _dungeon.tileAt(x, y);
    if (tile == m.TileType.wall || tile == m.TileType.water) return false;
    if (tile == m.TileType.door && !_openedDoors.contains('$x,$y')) return false;
    if (_solidPropPositions.contains('$x,$y')) return false;
    return true;
  }

  int _roamTurnCounter = 0;

  void _roamNpcs() {
    _roamTurnCounter++;
    if (_roamTurnCounter % 2 != 0) return;
    if (_npcs.isEmpty) return;

    final occupied = <String>{
      '${playerPos.x},${playerPos.y}',
      for (final p in _props) '${p.pos.x},${p.pos.y}',
    };
    final campaign = ref.read(campaignProvider);
    if (campaign != null) {
      for (final m in campaign.party) {
        if (m.position != null) occupied.add('${m.position!.x},${m.position!.y}');
      }
    }

    final rng = Random();
    final updated = <MapNpc>[];
    const deltas = [m.Point(1, 0), m.Point(-1, 0), m.Point(0, 1), m.Point(0, -1)];

    for (final npc in _npcs) {
      if (npc.currentHp <= 0) continue;
      m.Point current = npc.pos;
      m.Point target = current;

      if (npc.isHostile) {
        final dist = (current.x - playerPos.x).abs() + (current.y - playerPos.y).abs();
        if (dist <= 4 && rng.nextDouble() < 0.65) {
          // Stalk towards player
          final dx = (playerPos.x - current.x).sign;
          final dy = (playerPos.y - current.y).sign;
          final moves = <m.Point>[];
          if (dx != 0) moves.add(m.Point(current.x + dx, current.y));
          if (dy != 0) moves.add(m.Point(current.x, current.y + dy));
          moves.shuffle(rng);

          for (final candidate in moves) {
            final key = '${candidate.x},${candidate.y}';
            if (_isWalkableTile(candidate.x, candidate.y) && !occupied.contains(key)) {
              target = candidate;
              break;
            }
          }
        } else if (rng.nextDouble() < 0.30) {
          // Patrol wander
          final valid = <m.Point>[];
          for (final d in deltas) {
            final nx = current.x + d.x;
            final ny = current.y + d.y;
            if (_isWalkableTile(nx, ny) && !occupied.contains('$nx,$ny')) {
              valid.add(m.Point(nx, ny));
            }
          }
          if (valid.isNotEmpty) {
            target = valid[rng.nextInt(valid.length)];
          }
        }
      } else {
        // Friendly / neutral wanderer: 45% chance to wander
        if (rng.nextDouble() < 0.45) {
          final valid = <m.Point>[];
          for (final d in deltas) {
            final nx = current.x + d.x;
            final ny = current.y + d.y;
            if (_isWalkableTile(nx, ny) && !occupied.contains('$nx,$ny')) {
              valid.add(m.Point(nx, ny));
            }
          }
          if (valid.isNotEmpty) {
            target = valid[rng.nextInt(valid.length)];
          }
        }
      }

      occupied.add('${target.x},${target.y}');
      updated.add(npc.copyWith(pos: target));
    }

    setState(() {
      _npcs = updated;
    });
  }

  void _roamAnimals() {
    if (_animals.isEmpty) return;
    final rng = Random();
    final occupied = <String>{
      '${playerPos.x},${playerPos.y}',
      for (final p in _props) '${p.pos.x},${p.pos.y}',
      for (final n in _npcs) '${n.pos.x},${n.pos.y}',
      ..._solidPropPositions,
    };
    final campaign = ref.read(campaignProvider);
    if (campaign != null) {
      for (final m in campaign.party) {
        if (m.position != null) occupied.add('${m.position!.x},${m.position!.y}');
      }
    }

    final updated = <MapAnimal>[];
    const deltas = [m.Point(1, 0), m.Point(-1, 0), m.Point(0, 1), m.Point(0, -1)];

    for (final animal in _animals) {
      m.Point current = animal.pos;
      m.Point target = current;

      if (rng.nextDouble() < 0.35) {
        final valid = <m.Point>[];
        for (final d in deltas) {
          final nx = current.x + d.x;
          final ny = current.y + d.y;
          if (_isWalkableTile(nx, ny) && !occupied.contains('$nx,$ny')) {
            valid.add(m.Point(nx, ny));
          }
        }
        if (valid.isNotEmpty) {
          target = valid[rng.nextInt(valid.length)];
        }
      }

      occupied.add('${target.x},${target.y}');
      updated.add(animal.copyWith(pos: target));
    }

    setState(() {
      _animals = updated;
    });
  }

  void _move(int dx, int dy) {
    final nx = playerPos.x + dx;
    final ny = playerPos.y + dy;
    if (nx < 0 || ny < 0 || nx >= _dungeon.width || ny >= _dungeon.height) return;
    final tile = _dungeon.tileAt(nx, ny);
    if (tile == m.TileType.wall || tile == m.TileType.water) return;

    // Check closed door
    if (tile == m.TileType.door && !_openedDoors.contains('$nx,$ny')) {
      _showDoorInteractionDialog(m.Point(nx, ny));
      return;
    }

    // Check solid furniture or obstacle
    final prop = _props.where((p) => p.pos.x == nx && p.pos.y == ny).firstOrNull;
    if (prop != null && prop.isSolid) {
      _handlePropTap(prop);
      return;
    }

    // Check animal on tile
    final animal = _animals.where((a) => a.pos.x == nx && a.pos.y == ny).firstOrNull;
    if (animal != null) {
      _showAnimalInteractionDialog(animal);
      return;
    }

    // Check NPC on tile
    final npc = _npcs.where((n) => n.pos.x == nx && n.pos.y == ny).firstOrNull;
    if (npc != null) {
      _handleNpcTap(npc);
      return;
    }

    final campaign = ref.read(campaignProvider);
    final chars = ref.read(savedCharactersProvider);
    final activePet = _getActivePet(campaign, chars);
    final visionRad = activePet?.id == 'spectral_owl' ? 3 : 2;
    final prevLeaderPos = Point(playerPos.x, playerPos.y);

    setState(() {
      playerPos = m.Point(nx, ny);
      visited.add('$nx,$ny');

      // Companion trail march formation behind the leader
      if (campaign != null && campaign.party.length > 1) {
        Point trailPos = prevLeaderPos;
        for (var i = 1; i < campaign.party.length; i++) {
          final currentMemberPos = campaign.party[i].position ?? prevLeaderPos;
          campaign.party[i].position = trailPos;
          trailPos = currentMemberPos;
          visited.add('${campaign.party[i].position!.x},${campaign.party[i].position!.y}');
          campaign.visitedTiles.add('${campaign.party[i].position!.x},${campaign.party[i].position!.y}');
        }
      }

      for (var yOff = -visionRad; yOff <= visionRad; yOff++) {
        for (var xOff = -visionRad; xOff <= visionRad; xOff++) {
          final vx = nx + xOff;
          final vy = ny + yOff;
          if (vx >= 0 && vy >= 0 && vx < _dungeon.width && vy < _dungeon.height) {
            visited.add('$vx,$vy');
            campaign?.visitedTiles.add('$vx,$vy');
          }
        }
      }
    });
    ref.read(campaignProvider.notifier).moveTo(Point(nx, ny));
    _recenterOnPlayer();
    _roamNpcs();
    _roamAnimals();
    _broadcastTvState();

    // Check newly discovered rooms
    for (final room in _dungeon.rooms) {
      if (room.contains(m.Point(nx, ny)) && !_discoveredRoomIds.contains(room.id)) {
        _discoveredRoomIds.add(room.id);
        _onRoomDiscovered(room);
        break;
      }
    }

    // Tavern Hound trap detection alert
    if (activePet?.id == 'tavern_hound') {
      final nearbyTrap = _traps.firstWhere(
        (t) {
          final parts = t.split(',');
          final tx = int.tryParse(parts[0]) ?? -99;
          final ty = int.tryParse(parts[1]) ?? -99;
          return (nx - tx).abs() + (ny - ty).abs() <= 2;
        },
        orElse: () => '',
      );
      if (nearbyTrap.isNotEmpty && !_revealedTraps.contains(nearbyTrap)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🐕 Tavern Hound alerts! It sniffs the stone and whimpers softly — a trap is nearby!', style: GoogleFonts.ibmPlexSans()),
            backgroundColor: const Color(0xFFFFA726),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // Check if player triggered an undiscovered trap
    final posKey = '$nx,$ny';
    if (_traps.contains(posKey) && !_revealedTraps.contains(posKey)) {
      _traps.remove(posKey);
      _revealedTraps.add(posKey);
      _props.add(MapProp(pos: m.Point(nx, ny), asset: 'assets/tiles/prop_rubble.png', isSolid: false));
      AudioService.instance.playError();
      final trapDmg = Random().nextInt(4) + 2;
      if (campaign != null && campaign.party.isNotEmpty) {
        ref.read(campaignProvider.notifier).updateHp(campaign.party.first.characterId, -trapDmg);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('TRAP TRIGGERED! Concealed darts spring from the wall! (-$trapDmg HP)', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      _send('A hidden pressure plate clicks beneath my foot! Poison darts spray out, dealing $trapDmg damage!');
      return;
    }

    // auto describe
    _send('I move to the next area.');
    _checkMapQuestProgression();
    _checkSidequestProgression(atPos: m.Point(nx, ny));
  }

  void _checkMapQuestProgression() {
    final campaign = ref.read(campaignProvider);
    if (campaign == null || campaign.questLog.isEmpty) return;
    final currentBeatIndex = campaign.questLog.indexWhere((q) => q.status == 'active');
    if (currentBeatIndex == -1) return;

    final tilesCount = visited.length;
    final doorsCount = _openedDoors.length;
    final defeatedCount = campaign.defeatedEnemies.length;
    final depth = campaign.worldFlags['dungeonDepth'] as int? ?? 1;

    bool shouldAdvance = false;
    String milestoneText = '';

    if (currentBeatIndex == 0) {
      // Beat 1: Scout entrance / tavern (explore at least 12 tiles or open 1 door)
      if (tilesCount >= 12 || doorsCount >= 1) {
        shouldAdvance = true;
        milestoneText = 'Corridor charted! You uncover the path into the depths.';
      }
    } else if (currentBeatIndex == 1) {
      // Beat 2: Defeat a foe, disarm a trap, or uncover a chest
      if (defeatedCount >= 1 || _revealedTraps.isNotEmpty || _props.any((p) => p.asset.contains('chest'))) {
        shouldAdvance = true;
        milestoneText = 'Perils overcome! The ancient mysteries begin to unravel.';
      }
    } else if (currentBeatIndex == 2) {
      // Beat 3: Reach Depth 2 via stairs or commune with mystic shrine
      if (depth >= 2 || _props.any((p) => (p.asset.contains('pillar') || p.asset.contains('altar')) && (p.pos.x - playerPos.x).abs() + (p.pos.y - playerPos.y).abs() <= 1)) {
        shouldAdvance = true;
        milestoneText = 'Sacred grounds reached! The binding sigils resonate.';
      }
    } else if (currentBeatIndex == 3) {
      // Beat 4: Deep sanctum exploration & guardian encounter
      if (depth >= 2 && (defeatedCount >= 2 || tilesCount >= 35)) {
        shouldAdvance = true;
        milestoneText = 'Deep sanctum breached! The final confrontation awaits.';
      }
    }

    if (shouldAdvance && currentBeatIndex < campaign.questLog.length - 1) {
      final nextBeat = currentBeatIndex + 1;
      ref.read(campaignProvider.notifier).advanceQuestBeat(nextBeat);
      AudioService.instance.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'QUEST OBJECTIVE ADVANCED!\n$milestoneText',
                  style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: ArcaneTheme.primary,
          duration: const Duration(seconds: 4),
        ),
      );
      _send('The party makes significant headway into the dungeon! $milestoneText');
    }
  }

  Set<String> get _closedDoors {
    final set = <String>{};
    for (var y = 0; y < _dungeon.height; y++) {
      for (var x = 0; x < _dungeon.width; x++) {
        if (_dungeon.tileAt(x, y) == m.TileType.door && !_openedDoors.contains('$x,$y')) {
          set.add('$x,$y');
        }
      }
    }
    return set;
  }

  Future<void> _handleTileTap(m.Point target) async {
    if (_isTraversing) return;
    if (target.x == playerPos.x && target.y == playerPos.y) return;

    // Check if tapping a prop directly
    final prop = _props.where((p) => p.pos.x == target.x && p.pos.y == target.y).firstOrNull;
    if (prop != null) {
      _handlePropTap(prop);
      return;
    }

    // Check if tapping an animal directly
    final animal = _animals.where((a) => a.pos.x == target.x && a.pos.y == target.y).firstOrNull;
    if (animal != null) {
      _showAnimalInteractionDialog(animal);
      return;
    }

    // Check if tapping an NPC directly
    final npc = _npcs.where((n) => n.pos.x == target.x && n.pos.y == target.y).firstOrNull;
    if (npc != null) {
      _handleNpcTap(npc);
      return;
    }

    final isDoor = _dungeon.tileAt(target.x, target.y) == m.TileType.door;
    final isDoorClosed = isDoor && !_openedDoors.contains('${target.x},${target.y}');
    final distToTarget = (playerPos.x - target.x).abs() + (playerPos.y - target.y).abs();

    if (isDoorClosed && distToTarget <= 1) {
      _showDoorInteractionDialog(target);
      return;
    }

    final path = m.findPath(_dungeon, playerPos, target, closedDoors: _closedDoors, blockedTiles: _solidPropPositions);
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tile unreachable or blocked by stone barrier / solid furniture', style: GoogleFonts.ibmPlexSans()),
          duration: const Duration(milliseconds: 750),
          backgroundColor: ArcaneTheme.tertiary,
        ),
      );
      return;
    }

    setState(() {
      _targetWaypoint = target;
      _activePath = path;
      _isTraversing = true;
    });

    final campaign = ref.read(campaignProvider);
    final chars = ref.read(savedCharactersProvider);
    final activePet = _getActivePet(campaign, chars);
    final visionRad = activePet?.id == 'spectral_owl' ? 3 : 2;

    for (var i = 0; i < path.length; i++) {
      if (!mounted) break;
      final step = path[i];

      // If step is an unopened door, stop before passing through
      if (_dungeon.tileAt(step.x, step.y) == m.TileType.door && !_openedDoors.contains('${step.x},${step.y}')) {
        setState(() {
          _isTraversing = false;
          _activePath = null;
          _targetWaypoint = null;
        });
        _showDoorInteractionDialog(step);
        return;
      }

      setState(() {
        playerPos = step;
        visited.add('${step.x},${step.y}');
        if (campaign != null) {
          campaign.visitedTiles.add('${step.x},${step.y}');
        }

        for (var dy = -visionRad; dy <= visionRad; dy++) {
          for (var dx = -visionRad; dx <= visionRad; dx++) {
            final nx = step.x + dx;
            final ny = step.y + dy;
            if (nx >= 0 && ny >= 0 && nx < _dungeon.width && ny < _dungeon.height) {
              visited.add('$nx,$ny');
              if (campaign != null) {
                campaign.visitedTiles.add('$nx,$ny');
              }
            }
          }
        }

        // Companion trail formation behind the leader
        if (campaign != null && campaign.party.length > 1 && i > 0) {
          for (var c = 1; c < campaign.party.length; c++) {
            final trailIdx = i - c;
            if (trailIdx >= 0) {
              final t = path[trailIdx];
              campaign.party[c].position = Point(t.x, t.y);
              visited.add('${t.x},${t.y}');
              campaign.visitedTiles.add('${t.x},${t.y}');
            }
          }
        }
      });

      // Check newly discovered rooms
      for (final room in _dungeon.rooms) {
        if (room.contains(step) && !_discoveredRoomIds.contains(room.id)) {
          _discoveredRoomIds.add(room.id);
          _onRoomDiscovered(room);
          break;
        }
      }

      if (i % 2 == 0) {
        AudioService.instance.playTap();
      }

      // Check if stepped directly onto a concealed trap
      final stepKey = '${step.x},${step.y}';
      if (_traps.contains(stepKey) && !_revealedTraps.contains(stepKey)) {
        _traps.remove(stepKey);
        _revealedTraps.add(stepKey);
        _props.add(MapProp(pos: step, asset: 'assets/tiles/prop_rubble.png', isSolid: false));
        AudioService.instance.playError();
        final trapDmg = Random().nextInt(4) + 2;
        if (campaign != null && campaign.party.isNotEmpty) {
          ref.read(campaignProvider.notifier).updateHp(campaign.party.first.characterId, -trapDmg);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('TRAP TRIGGERED! Poison darts spray from the wall! (-$trapDmg HP)', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
        _send('A hidden pressure plate clicks beneath my foot! Poison darts spray out, dealing $trapDmg damage!');
        break;
      }

      // Check if stepped adjacent to a hostile enemy
      final adjacentEnemy = _npcs.where((n) => n.isHostile && (n.pos.x - step.x).abs() + (n.pos.y - step.y).abs() <= 1).firstOrNull;
      if (adjacentEnemy != null) {
        AudioService.instance.playError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ENEMY ALERT! ${adjacentEnemy.name} confronts the party!', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
            backgroundColor: Colors.red.shade900,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      }

      await Future.delayed(const Duration(milliseconds: 90));
    }

    if (mounted) {
      setState(() {
        _isTraversing = false;
        _activePath = null;
        _targetWaypoint = null;
      });
      ref.read(campaignProvider.notifier).moveTo(Point(playerPos.x, playerPos.y));
      _recenterOnPlayer();
      _roamNpcs();
      _roamAnimals();
      _broadcastTvState();

      final tile = _dungeon.tileAt(playerPos.x, playerPos.y);
      final desc = tile == m.TileType.door ? 'through the doorway' : 'into the chamber';
      _send('I traverse the corridor $desc.');
      _checkMapQuestProgression();
      _checkSidequestProgression(atPos: playerPos);
    }
  }

  void _showAnimalInteractionDialog(MapAnimal animal) {
    AudioService.instance.playTap();
    final campaign = ref.read(campaignProvider);
    final chars = ref.read(savedCharactersProvider);
    final activePet = _getActivePet(campaign, chars);
    final isCurrentPet = activePet?.id == animal.petId;

    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ArcaneTheme.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.5)),
              ),
              child: Text(animal.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(animal.name.toUpperCase(), style: GoogleFonts.cinzel(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text('${animal.species.toUpperCase()} • ${animal.flavor}', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.secondary, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
            child: Text('"${animal.dialogue}"', style: GoogleFonts.spectral(fontSize: 13.5, fontStyle: FontStyle.italic, color: Colors.white70)),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.pets_rounded, size: 16),
                label: const Text('Pet Gently'),
                onPressed: () {
                  Navigator.pop(ctx);
                  AudioService.instance.playTap();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('You gently pet ${animal.name}. It leans into your touch with deep affection!', style: GoogleFonts.ibmPlexSans()),
                      backgroundColor: ArcaneTheme.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  _send('I reach out gently to pet ${animal.name}. It leans into my hand with warmth and comfort.');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.lunch_dining_rounded, size: 16),
                label: const Text('Feed Treat'),
                onPressed: () {
                  Navigator.pop(ctx);
                  AudioService.instance.playSuccess();
                  if (campaign != null && campaign.party.isNotEmpty) {
                    ref.read(campaignProvider.notifier).updateHp(campaign.party.first.characterId, 2);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('You feed a treat to ${animal.name}! It happily munches and grants comfort (+2 HP).', style: GoogleFonts.ibmPlexSans()),
                      backgroundColor: const Color(0xFF3DD68C),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  _send('I share a savory bit of travel rations with ${animal.name}. It munches the treat happily and perks up beside us.');
                },
              ),
            ),
          ]),
          if (animal.canAdopt && animal.petId.isNotEmpty && !isCurrentPet) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.volunteer_activism_rounded, size: 17),
                label: Text('Adopt ${animal.name} as Pet Companion', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: ArcaneTheme.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  AudioService.instance.playSuccess();
                  if (campaign != null && campaign.party.isNotEmpty) {
                    final leadId = campaign.party.first.characterId;
                    final leadChar = chars.where((c) => c.id == leadId).firstOrNull;
                    if (leadChar != null) {
                      final updated = leadChar.copyWith(avatar: leadChar.avatar.copyWith(pet: animal.petId));
                      await ref.read(savedCharactersProvider.notifier).updateCharacter(updated);
                    }
                  }
                  setState(() {
                    _animals.removeWhere((a) => a.id == animal.id);
                  });
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${animal.name} is now your loyal Pet Companion! It will follow you through all dungeons and taverns.', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                      backgroundColor: ArcaneTheme.primary,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _send('I kneel down and welcome ${animal.name} into our party as our loyal pet companion! It trots happily alongside us.');
                },
              ),
            ),
          ],
        ]),
      ),
    );
  }

  void _showDoorInteractionDialog(m.Point doorPos) {
    AudioService.instance.playTap();
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ArcaneTheme.secondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.meeting_room_rounded, color: ArcaneTheme.secondary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('HEAVY DUNGEON DOOR', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Stout timber reinforced with iron bands.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('You stand at the portal. How does the party proceed?', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.hearing_rounded, size: 16),
                label: const Text('Listen'),
                onPressed: () {
                  Navigator.pop(ctx);
                  final d20 = Random().nextInt(20) + 1;
                  final total = d20 + 2;
                  AudioService.instance.playDiceRoll();
                  final heard = total >= 12
                      ? 'faint skittering claws and raspy murmurs in the dark chamber beyond!'
                      : 'only the slow dripping of condensation upon stone.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Perception [$total]: $heard', style: GoogleFonts.ibmPlexSans()),
                      duration: const Duration(seconds: 3),
                      backgroundColor: ArcaneTheme.primary,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.door_front_door_outlined, size: 16),
                label: const Text('Push Open'),
                style: ElevatedButton.styleFrom(backgroundColor: ArcaneTheme.primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _openedDoors.add('${doorPos.x},${doorPos.y}');
                    for (var dy = -3; dy <= 3; dy++) {
                      for (var dx = -3; dx <= 3; dx++) {
                        final nx = doorPos.x + dx;
                        final ny = doorPos.y + dy;
                        if (nx >= 0 && ny >= 0 && nx < _dungeon.width && ny < _dungeon.height) {
                          visited.add('$nx,$ny');
                          ref.read(campaignProvider)?.visitedTiles.add('$nx,$ny');
                        }
                      }
                    }
                  });
                  ref.read(campaignProvider.notifier).openDoor(doorPos.x, doorPos.y);
                  if (widget.sessionId != null && _isMultiplayerHost == true) {
                    final c = ref.read(campaignProvider);
                    if (c != null) SessionRepository.instance.pushState(widget.sessionId!, c);
                  }
                  AudioService.instance.playSuccess();
                  _send('I turn the rusted iron ring and push open the heavy dungeon door.');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _handleNpcTap(MapNpc npc) {
    if (!npc.isHostile) {
      _showNpcInteractionDialog(npc);
      return;
    }
    _showCombatDialog(npc);
  }

  void _showNpcInteractionDialog(MapNpc npc) {
    final campaign = ref.read(campaignProvider);
    if (campaign == null) return;
    AudioService.instance.playTap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NpcInteractionSheet(
        npc: npc,
        campaign: campaign,
        onConverse: (prompt) {
          _send(prompt);
        },
        onBuyItem: (item) {
          final activeHero = campaign.party.firstOrNull;
          if (activeHero != null) {
            ref.read(campaignProvider.notifier).addItem(activeHero.characterId, item);
          }
        },
        onHealParty: (amount) {
          for (final hero in campaign.party) {
            ref.read(campaignProvider.notifier).updateHp(hero.characterId, amount);
          }
        },
        onRecruit: (recruitedNpc) {
          final newMember = PartyMemberStatus(
            characterId: 'comp_${recruitedNpc.id}_${DateTime.now().millisecondsSinceEpoch}',
            name: recruitedNpc.name,
            raceLabel: recruitedNpc.role.contains('Elf') ? 'Elf' : (recruitedNpc.role.contains('Dwarf') ? 'Dwarf' : 'Human'),
            classLabel: recruitedNpc.role,
            persona: recruitedNpc.greeting ?? 'A skilled dungeon wanderer.',
            abilities: AbilityScores(str: 14, dex: 13, con: 14, int_: 12, wis: 14, cha: 12),
            hp: recruitedNpc.maxHp,
            maxHp: recruitedNpc.maxHp,
            armorClass: recruitedNpc.armorClass,
            inventory: List.from(recruitedNpc.shopItems),
          );
          ref.read(campaignProvider.notifier).addPartyMemberStatus(newMember);
          setState(() {
            _npcs.removeWhere((n) => n.id == recruitedNpc.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${recruitedNpc.name} has joined your party!', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
              backgroundColor: ArcaneTheme.primary,
              duration: const Duration(seconds: 3),
            ),
          );
          _send('I welcome ${recruitedNpc.name} to our party of adventurers!');
        },
        onChallenge: (hostileNpc) {
          setState(() {
            final idx = _npcs.indexWhere((n) => n.id == hostileNpc.id);
            if (idx != -1) {
              _npcs[idx] = hostileNpc;
            } else {
              _npcs.add(hostileNpc);
            }
          });
          _showCombatDialog(hostileNpc);
        },
      ),
    );
  }

  void _showCombatDialog(MapNpc enemy) {
    final campaign = ref.read(campaignProvider);
    if (campaign == null) return;
    AudioService.instance.playError();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TacticalCombatSheet(
        initialEnemy: enemy,
        campaign: campaign,
        activePet: _getActivePet(campaign, ref.read(savedCharactersProvider)),
        onEnemyUpdated: (updatedEnemy) {
          setState(() {
            final idx = _npcs.indexWhere((n) => n.id == updatedEnemy.id);
            if (idx != -1) {
              _npcs[idx] = updatedEnemy;
            }
          });
        },
        onEnemyDefeated: (defeatedEnemy) {
          setState(() {
            _npcs.removeWhere((n) => n.id == defeatedEnemy.id);
            _props.add(MapProp(pos: defeatedEnemy.pos, asset: 'assets/tiles/prop_bones.png'));
          });
          ref.read(campaignProvider.notifier).defeatEnemy(defeatedEnemy.id);
          if (widget.sessionId != null && _isMultiplayerHost == true) {
            final c = ref.read(campaignProvider);
            if (c != null) SessionRepository.instance.pushState(widget.sessionId!, c);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ENEMY SLAIN: ${defeatedEnemy.name}! The party gains +50 XP and clears the chamber.', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
              backgroundColor: ArcaneTheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onHeroDamaged: (characterId, dmg) {
          ref.read(campaignProvider.notifier).updateHp(characterId, -dmg);
        },
        onCombatNarration: (narration) {
          _send(narration);
        },
      ),
    );
  }

  void _performAttackAction() {
    final hostiles = _npcs.where((n) => n.isHostile).toList()
      ..sort((a, b) => ((a.pos.x - playerPos.x).abs() + (a.pos.y - playerPos.y).abs()).compareTo((b.pos.x - playerPos.x).abs() + (b.pos.y - playerPos.y).abs()));
    if (hostiles.isNotEmpty) {
      _showCombatDialog(hostiles.first);
    } else {
      final campaign = ref.read(campaignProvider);
      final foeName = campaign != null && campaign.seed.villain.isNotEmpty
          ? '${campaign.seed.villain.split(' ').first} Minion'
          : 'Spire Ice Wraith';
      final ambush = MapNpc(
        id: 'ambush_${DateTime.now().millisecondsSinceEpoch}',
        name: foeName,
        role: 'Hostile Stalker',
        pos: m.Point(playerPos.x + 1, playerPos.y),
        portraitAsset: 'assets/avatar/portraits/orc.png',
        isHostile: true,
        maxHp: 16,
        currentHp: 16,
        armorClass: 12,
        attackBonus: 4,
        damageDice: 6,
        attackName: 'Frost Claws',
        greeting: 'An icy fiend leaps from the frozen mist!',
      );
      setState(() {
        _npcs.add(ambush);
      });
      _showCombatDialog(ambush);
    }
  }

  void _performSearchAction() {
    AudioService.instance.playDiceRoll();
    final campaign = ref.read(campaignProvider);
    final chars = ref.read(savedCharactersProvider);
    final activePet = _getActivePet(campaign, chars);
    final houndBonus = activePet?.id == 'tavern_hound' ? 2 : 0;
    final d20 = Random().nextInt(20) + 1;
    final total = d20 + 3 + houndBonus; // +3 perception, +2 with Tavern Hound
    if (total >= 12) {
      AudioService.instance.playSuccess();

      // 1. Check if an undiscovered trap is nearby (within distance 2)
      final nearbyTrap = _traps.firstWhere(
        (t) {
          final parts = t.split(',');
          final tx = int.tryParse(parts[0]) ?? -99;
          final ty = int.tryParse(parts[1]) ?? -99;
          return (playerPos.x - tx).abs() + (playerPos.y - ty).abs() <= 2;
        },
        orElse: () => '',
      );
      if (nearbyTrap.isNotEmpty) {
        _traps.remove(nearbyTrap);
        _revealedTraps.add(nearbyTrap);
        final parts = nearbyTrap.split(',');
        final tx = int.parse(parts[0]);
        final ty = int.parse(parts[1]);
        setState(() {
          _props.add(MapProp(pos: m.Point(tx, ty), asset: 'assets/tiles/prop_rubble.png', isSolid: false));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perception [$total${houndBonus > 0 ? " (+2 Hound)" : ""}]: TRAP DETECTED! You spot a concealed tripwire at ($tx,$ty)! (Marked with rubble)', style: GoogleFonts.ibmPlexSans()),
            backgroundColor: ArcaneTheme.secondary,
            duration: const Duration(seconds: 3),
          ),
        );
        _send('My keen perception catches a hairline tripwire in the flagstones (Perception: $total). I mark the trap with rubble so the party avoids it!');
        return;
      }

      final adjacentSpots = [
        m.Point(playerPos.x + 1, playerPos.y),
        m.Point(playerPos.x - 1, playerPos.y),
        m.Point(playerPos.x, playerPos.y + 1),
        m.Point(playerPos.x, playerPos.y - 1),
      ].where((p) => p.x >= 0 && p.y >= 0 && p.x < _dungeon.width && p.y < _dungeon.height && _dungeon.tileAt(p.x, p.y) == m.TileType.floor).toList();

      if (adjacentSpots.isNotEmpty && Random().nextDouble() < 0.45) {
        final stashSpot = adjacentSpots.first;
        final hasProp = _props.any((p) => p.pos.x == stashSpot.x && p.pos.y == stashSpot.y);
        if (!hasProp) {
          setState(() {
            _props.add(MapProp(pos: stashSpot, asset: 'assets/tiles/prop_chest.png', isSolid: true, name: 'Dungeon Chest'));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Perception [$total]: SUCCESS! You uncover a concealed iron coffer beneath a flagstone!', style: GoogleFonts.ibmPlexSans()),
              backgroundColor: ArcaneTheme.primary,
              duration: const Duration(seconds: 3),
            ),
          );
          _send('I inspect the stone floor (Perception: $total) and uncover a concealed iron coffer!');
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perception [$total${houndBonus > 0 ? " (+2 Hound)" : ""}]: SUCCESS! No hidden traps detected along the floor.', style: GoogleFonts.ibmPlexSans()),
          backgroundColor: ArcaneTheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      _send('I thoroughly search the surrounding stonework for traps and hidden mechanisms (Perception: $total).');
    } else {
      AudioService.instance.playTap();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perception [$total]: The dust and shadows reveal nothing unusual.', style: GoogleFonts.ibmPlexSans()),
          backgroundColor: ArcaneTheme.surfaceElevated,
          duration: const Duration(seconds: 2),
        ),
      );
      _send('I scan the chamber, finding only dust and age-old masonry (Perception: $total).');
    }
  }

  void _handlePropTap(MapProp prop) {
    final dist = (playerPos.x - prop.pos.x).abs() + (playerPos.y - prop.pos.y).abs();
    if (dist > 1) {
      final neighbors = [
        m.Point(prop.pos.x + 1, prop.pos.y),
        m.Point(prop.pos.x - 1, prop.pos.y),
        m.Point(prop.pos.x, prop.pos.y + 1),
        m.Point(prop.pos.x, prop.pos.y - 1),
      ].where((p) => _isWalkableTile(p.x, p.y) && !_solidPropPositions.contains('${p.x},${p.y}')).toList();
      if (neighbors.isNotEmpty) {
        neighbors.sort((a, b) => ((a.x - playerPos.x).abs() + (a.y - playerPos.y).abs()).compareTo((b.x - playerPos.x).abs() + (b.y - playerPos.y).abs()));
        _handleTileTap(neighbors.first);
      }
      return;
    }

    if (_dungeon.rooms.length > 1 && prop.pos.x == _dungeon.rooms.last.centerX && prop.pos.y == _dungeon.rooms.last.centerY) {
      _showDescentDialog();
    } else if (prop.asset.contains('altar') || (prop.asset.contains('pillar') && _dungeon.rooms.length > 2 && prop.pos.x == _dungeon.rooms[1].centerX && prop.pos.y == _dungeon.rooms[1].centerY)) {
      _showAltarDialog(prop);
    } else if (prop.asset.contains('chest_gilded')) {
      _showGildedChestDialog(prop);
    } else if (prop.asset.contains('chest')) {
      _showLootChestDialog(prop);
    } else if (prop.asset.contains('cauldron')) {
      _showCauldronDialog(prop);
    } else if (prop.asset.contains('lectern')) {
      _showLecternDialog(prop);
    } else if (prop.asset.contains('sarcophagus')) {
      _showSarcophagusDialog(prop);
    } else if (prop.asset.contains('brazier')) {
      _showBrazierDialog(prop);
    } else if (prop.asset.contains('statue')) {
      _showStatueDialog(prop);
    } else if (prop.asset.contains('crystals')) {
      _showCrystalDialog(prop);
    } else if (prop.asset.contains('crates')) {
      _showCratesDialog(prop);
    } else if (prop.asset.contains('campfire')) {
      _triggerCampfireBanter();
    } else if (prop.asset.contains('torch')) {
      AudioService.instance.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Torchflare! The warm glow banishes the shadows.', style: GoogleFonts.ibmPlexSans()),
          backgroundColor: ArcaneTheme.primary,
          duration: const Duration(seconds: 1),
        ),
      );
    } else if (prop.interactionText != null) {
      AudioService.instance.playTap();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${prop.name ?? "Inspection"}: ${prop.interactionText!}', style: GoogleFonts.ibmPlexSans()),
          backgroundColor: ArcaneTheme.surfaceElevated,
          duration: const Duration(seconds: 3),
        ),
      );
      _send('I inspect the ${prop.name ?? "object"} closely: ${prop.interactionText!}');
    } else {
      _send('I investigate the ${prop.asset.split('/').last.replaceAll('prop_', '').replaceAll('.png', '')} thoroughly.');
    }
  }

  void _showAltarDialog(MapProp prop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF3DD68C).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFF3DD68C), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MYSTIC SHRINE', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('An ancient stone obelisk radiating restorative energy.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Ancient celestial runes are etched into the marble. How does the party commune with the shrine?', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Channel Arcana'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _send('I channel the arcane runes on the obelisk to detect magical auras (Arcana check).');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.favorite_rounded, size: 16),
                label: const Text('Pray for Blessing'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3DD68C)),
                onPressed: () {
                  Navigator.pop(ctx);
                  final campaign = ref.read(campaignProvider);
                  if (campaign != null && campaign.party.isNotEmpty) {
                    ref.read(campaignProvider.notifier).updateHp(campaign.party.first.characterId, 8);
                  }
                  AudioService.instance.playSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Divine blessing received! +8 HP restored to the party.', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                      backgroundColor: const Color(0xFF3DD68C),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _send('I kneel before the mystic shrine in reverence. A wave of radiant light heals our wounds (+8 HP)!');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showLootChestDialog(MapProp prop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ArcaneTheme.secondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.stars_rounded, color: ArcaneTheme.secondary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DUNGEON CHEST', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Iron-banded coffer nestled in the crypt.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('You kneel before the coffer. How does the party proceed?', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.key_rounded, size: 16),
                label: const Text('Pick Lock'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _send('I carefully pick the lock on the ancient chest (Sleight of Hand).');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: const Text('Open & Loot'),
                style: ElevatedButton.styleFrom(backgroundColor: ArcaneTheme.primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  final items = [
                    'Potion of Greater Healing (+12 HP)',
                    'Scroll of Fireball (8d6 Fire)',
                    'Silvered Longsword (+1 ATK)',
                    'Elixir of Giant Strength (+2 STR)',
                    'Dagger of Venom (+1d6 Poison)',
                    'Ring of Protection (+1 AC)',
                    'Boots of Elvenkind (Advantage on Stealth)',
                    'Pouch of 65 Gold Coins'
                  ];
                  final loot = items[Random().nextInt(items.length)];
                  final campaign = ref.read(campaignProvider);
                  if (campaign != null && campaign.party.isNotEmpty) {
                    ref.read(campaignProvider.notifier).addItem(campaign.party.first.characterId, loot);
                  }
                  setState(() {
                    _props = _props.map((p) => p == prop ? p.copyWith(asset: 'assets/tiles/prop_chest_open.png', name: 'Opened Chest') : p).toList();
                  });
                  _broadcastTvState();
                  AudioService.instance.playSuccess();
                  _send('I pry open the chest and claim a $loot!');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showCauldronDialog(MapProp prop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF00E676).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.bubble_chart_rounded, color: Color(0xFF00E676), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ALCHEMICAL CAULDRON', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('A blackened iron pot brimming with bubbling verdant brew.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Aromatic vapors rise in spirals, invigorating all who stand near. How does the party interact with the brew?', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.science_rounded, size: 16),
                label: const Text('Study Brew'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _send('I analyze the boiling ingredients and herb mixtures inside the alchemical cauldron (Nature / Arcana check).');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.liquor_rounded, size: 16),
                label: const Text('Bottle Elixir'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                  final campaign = ref.read(campaignProvider);
                  if (campaign != null && campaign.party.isNotEmpty) {
                    ref.read(campaignProvider.notifier).updateHp(campaign.party.first.characterId, 8);
                    ref.read(campaignProvider.notifier).addItem(campaign.party.first.characterId, 'Draught of Vitality (+10 HP)');
                  }
                  AudioService.instance.playSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Elixir distilled! +8 HP restored and Draught of Vitality added to inventory.', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                      backgroundColor: const Color(0xFF00E676),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _send('I distill a steaming vial of the emerald elixir! The fumes restore +8 HP, and we bottle a Draught of Vitality.');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showLecternDialog(MapProp prop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF64B5F6).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF64B5F6), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ARCANE RUNIC LECTERN', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('An ancient grimoire resting on carved oak, pulsing with planar sigils.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Glowing draconic runes drift off the parchment like golden dust. How do you commune with the text?', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: const Text('Decipher Runes'),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _revealedTraps.addAll(_traps);
                    _traps.clear();
                  });
                  AudioService.instance.playSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Planar insight gained! All concealed crypt traps have been revealed on the map.', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                      backgroundColor: const Color(0xFF64B5F6),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _send('I chant the elder draconic verses inscribed upon the lectern! Arcane insight floods our minds, revealing hidden dungeon mechanisms.');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.menu_book_rounded, size: 16),
                label: const Text('Transcribe Spell'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF64B5F6), foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                  final campaign = ref.read(campaignProvider);
                  if (campaign != null && campaign.party.isNotEmpty) {
                    ref.read(campaignProvider.notifier).addItem(campaign.party.first.characterId, 'Scroll of Thunderwave (2d6 Thunder)');
                  }
                  AudioService.instance.playSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Spell transcribed! Scroll of Thunderwave added to party inventory.', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                      backgroundColor: const Color(0xFF64B5F6),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _send('I transcribe the resonant runes into our spellbook, creating a Scroll of Thunderwave (+20 XP)!');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showSarcophagusDialog(MapProp prop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFB300).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.masks_rounded, color: Color(0xFFFFB300), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CARVED STONE SARCOPHAGUS', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('A heavy limestone tomb etched with ancient funerary death masks.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Lead seals hold the massive lid shut. Prying it open might reveal ancient crypt relics—or awaken guardian horrors.', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Examine Epitaph'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _send('I carefully trace the faded epitaph on the limestone sarcophagus to honor the fallen noble (History check).');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.hardware_rounded, size: 16),
                label: const Text('Pry Open Lid'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                  final d20 = Random().nextInt(20) + 1;
                  final total = d20 + 3; // +3 athletics
                  if (total >= 11) {
                    final relics = ['Amulet of Health (+4 HP)', 'Ring of Protection (+1 AC)', 'Silvered Dagger of the Tomb', 'Pouch of 80 Ancient Coins'];
                    final relic = relics[Random().nextInt(relics.length)];
                    final campaign = ref.read(campaignProvider);
                    if (campaign != null && campaign.party.isNotEmpty) {
                      ref.read(campaignProvider.notifier).addItem(campaign.party.first.characterId, relic);
                    }
                    AudioService.instance.playSuccess();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Athletics [$total]: SUCCESS! Unsealed sarcophagus and retrieved $relic!', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                        backgroundColor: const Color(0xFF3DD68C),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    _send('With a heave of muscle (Athletics: $total), I pry loose the stone slab and unearth $relic!');
                  } else {
                    AudioService.instance.playError();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Athletics [$total]: The stone slab slips! A guardian shriek echoes in the crypt!', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    _send('I attempt to pry open the heavy tomb lid (Athletics: $total), but the stone resists, and a haunting moan echoes from below!');
                  }
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showGildedChestDialog(MapProp prop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFD54F).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD54F), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GILDED ROYAL COFFER', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('An ornate strongbox bound in gold filigree and royal heraldry.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('A complex runic cylinder secures the coffer. Legendary riches of the crypt vault are locked inside.', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.key_rounded, size: 16),
                label: const Text('Pick Cylinder'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _send('I use my finest thieves\' tools to manipulate the runic tumblers on the gilded coffer (Sleight of Hand).');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.stars_rounded, size: 16),
                label: const Text('Unlock Vault Loot'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                  final items = [
                    'Royal Sunblade (+2 ATK, Radiant)',
                    'Robe of the Archmagi (+2 AC, +10 HP)',
                    'Ring of Spell Storing',
                    'Belt of Dwarven Might (+2 CON)',
                    'Chest of 150 Royal Gold Pieces'
                  ];
                  final loot = items[Random().nextInt(items.length)];
                  final campaign = ref.read(campaignProvider);
                  if (campaign != null && campaign.party.isNotEmpty) {
                    ref.read(campaignProvider.notifier).addItem(campaign.party.first.characterId, loot);
                  }
                  setState(() {
                    _props = _props.map((p) => p == prop ? p.copyWith(asset: 'assets/tiles/prop_chest_open.png', name: 'Opened Vault Coffer') : p).toList();
                  });
                  _broadcastTvState();
                  AudioService.instance.playSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('VAULT UNLOCKED: Claimed $loot!', style: GoogleFonts.cinzel(fontWeight: FontWeight.w800, color: Colors.white)),
                      backgroundColor: const Color(0xFFFFD54F),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                  _send('I turn the final golden tumbler and swing open the gilded coffer, claiming $loot!');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showBrazierDialog(MapProp prop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFF6D00).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6D00), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CONSECRATED BRAZIER', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Perpetual holy flames crackling in an ancient bronze basin.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('The flames radiate comforting holy warmth that cuts right through subterranean despair. How does the party tend to the flame?', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.wb_sunny_rounded, size: 16),
                label: const Text('Warm the Party (+4 HP)'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  final campaign = ref.read(campaignProvider);
                  if (campaign != null) {
                    for (final hero in campaign.party) {
                      ref.read(campaignProvider.notifier).updateHp(hero.characterId, 4);
                    }
                  }
                  AudioService.instance.playSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Comforting holy warmth dispels fatigue! +4 HP restored to all companions.', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                      backgroundColor: const Color(0xFFFF6D00),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _send('The party gathers around the consecrated bronze brazier, soaking in the holy warmth to mend cuts and fatigue (+4 HP to all).');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showStatueDialog(MapProp prop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF635A7A).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.shield_rounded, color: Color(0xFFB8AFD1), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SENTINEL KNIGHT STATUE', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('A chiseled limestone warrior standing silent eternal vigil.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('The weathered effigy clutches an iron-trimmed greatsword planted firmly into the flagstones. An ancient knightly inscription is etched at its base.', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.favorite_rounded, size: 16),
                label: const Text('Kneel in Reverence (+4 HP)'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A5270), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  final campaign = ref.read(campaignProvider);
                  if (campaign != null && campaign.party.isNotEmpty) {
                    for (final hero in campaign.party) {
                      ref.read(campaignProvider.notifier).updateHp(hero.characterId, 4);
                    }
                  }
                  AudioService.instance.playSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('The spirit of the ancient sentinel honors your resolve! +4 HP to all heroes.', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                      backgroundColor: const Color(0xFF5A5270),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _send('The party bows before the Sentinel Knight Statue, feeling centuries of ancient valor surge through their veins (+4 HP to all).');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showCrystalDialog(MapProp prop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF00E5FF).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MANA CRYSTAL SPIRE', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Prismatic planar crystal humming with pure ley energy.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Resonant ethereal vibrations radiate from the crystal facets, soothing psychic fatigue and cleansing subterranean gloom.', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('Channel Ley Energy (+6 HP)'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B0FF), foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                  final campaign = ref.read(campaignProvider);
                  if (campaign != null && campaign.party.isNotEmpty) {
                    ref.read(campaignProvider.notifier).updateHp(campaign.party.first.characterId, 6);
                  }
                  AudioService.instance.playSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Arcane resonance flows into your soul! +6 HP restored.', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                      backgroundColor: const Color(0xFF00B0FF),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _send('I channel the resonant vibrations of the Mana Crystal Spire, feeling fresh arcane vitality restore my strength (+6 HP).');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showCratesDialog(MapProp prop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF8D6E63).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFBCAAA4), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SUPPLY CRATES & BARREL', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Stout timber containers bound in forged iron hoops.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('These supply munitions were abandoned by ancient crypt delve expeditions. Prying the lids open may reveal preserved supplies.', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Scavenge Supplies (+15 Gold)'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D4C41), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  final campaign = ref.read(campaignProvider);
                  if (campaign != null && campaign.party.isNotEmpty) {
                    ref.read(campaignProvider.notifier).addItem(campaign.party.first.characterId, 'Pouch of Ancient Coins (15 GP)');
                  }
                  AudioService.instance.playSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rummaging yields useful delve supplies and +15 Gold pieces!', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
                      backgroundColor: const Color(0xFF6D4C41),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _send('I pry open the heavy wooden crates and barrel, uncovering rations, replacement torch pitch, and 15 ancient gold coins!');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _onRoomDiscovered(m.Room room) {
    AudioService.instance.playSuccess();
    final campaign = ref.read(campaignProvider);
    if (campaign != null && campaign.party.isNotEmpty) {
      ref.read(campaignProvider.notifier).updateHp(campaign.party.first.characterId, 2);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(room.type.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DISCOVERED: ${room.name.toUpperCase()} (+15 XP)',
                      style: GoogleFonts.cinzel(fontWeight: FontWeight.w800, color: Colors.amberAccent, fontSize: 12.5)),
                  Text(room.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSans(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E2638),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _send('The party breaches ${room.name} (${room.type.icon}): ${room.description}');
    _broadcastTvState();
  }

  void _broadcastTvState() {
    if (!TvCastService.instance.isRunning && TvCastService.instance.connectedClientsCount == 0) return;
    final campaign = ref.read(campaignProvider);
    final chars = ref.read(savedCharactersProvider);
    final activeBeat = campaign?.questLog.where((q) => q.status == 'active').firstOrNull;

    final wallCoords = <Map<String, int>>[];
    for (var y = 0; y < _dungeon.height; y++) {
      for (var x = 0; x < _dungeon.width; x++) {
        final t = _dungeon.tileAt(x, y);
        if (t == m.TileType.wall || t == m.TileType.mountain) {
          final isNearVisited = visited.any((v) {
            final parts = v.split(',');
            final vx = int.tryParse(parts[0]) ?? -99;
            final vy = int.tryParse(parts[1]) ?? -99;
            return (x - vx).abs() <= 3 && (y - vy).abs() <= 3;
          });
          if (isNearVisited) {
            wallCoords.add({'x': x, 'y': y});
          }
        }
      }
    }

    final partyList = <Map<String, dynamic>>[];
    if (campaign != null && campaign.party.isNotEmpty) {
      for (final p in campaign.party) {
        final c = chars.where((ch) => ch.id == p.characterId).firstOrNull;
        partyList.add({
          'name': p.name,
          'hp': p.hp,
          'maxHp': p.maxHp,
          'raceClass': '${p.raceLabel} ${p.classLabel}',
          'icon': c != null ? '🛡️' : '⚔️',
        });
      }
    } else {
      partyList.add({
        'name': 'Valgar Bloodscale',
        'hp': 16,
        'maxHp': 16,
        'raceClass': 'Dragonborn Paladin',
        'icon': '🛡️',
      });
    }

    final propList = _props.map((p) => {
      'x': p.pos.x,
      'y': p.pos.y,
      'asset': p.asset,
      'name': p.name ?? 'Object',
    }).toList();

    final activePet = _getActivePet(campaign, chars);

    TvCastService.instance.broadcastState({
      'campaignTitle': campaign?.seed.title ?? 'Dungeon Delve',
      'quest': activeBeat?.title ?? 'Explore the Crypt',
      'depth': campaign?.worldFlags['dungeonDepth'] ?? 1,
      'playerPos': {'x': playerPos.x, 'y': playerPos.y},
      'visited': visited.toList(),
      'walls': wallCoords,
      'props': propList,
      'party': partyList,
      'pet': activePet != null && activePet.id != 'none'
          ? {
              'id': activePet.id,
              'name': activePet.name,
              'emoji': activePet.emoji,
              'perk': activePet.perkTitle,
              'color': '#${activePet.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
            }
          : null,
    });
  }

  void _showPetInteractionDialog(PetCompanion pet) {
    AudioService.instance.playTap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF140F22),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: pet.color.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: pet.color.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pet.color.withValues(alpha: 0.2),
                      border: Border.all(color: pet.color, width: 2),
                    ),
                    child: Center(child: Text(pet.emoji, style: const TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          pet.perkTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pet.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  pet.flavor,
                  style: GoogleFonts.spectral(
                    fontStyle: FontStyle.italic,
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pet.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pet.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(pet.icon, color: pet.color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pet.perkDescription,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pet.color.withValues(alpha: 0.25),
                        foregroundColor: Colors.white,
                        side: BorderSide(color: pet.color),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.favorite_rounded, size: 18),
                      label: const Text('Pet & Bond'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        AudioService.instance.playSuccess();
                        final bondMsg = '${pet.name} nuzzles into your hand happily. The bond strengthens your resolve! (+1 Inspiration)';
                        _appendDmNarration(bondMsg);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(bondMsg),
                            backgroundColor: const Color(0xFF2E1A47),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ArcaneTheme.primary.withValues(alpha: 0.3),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: ArcaneTheme.secondary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.explore_rounded, size: 18),
                      label: const Text('Scout Ahead'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _scoutWithPet(pet);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _scoutWithPet(PetCompanion pet) {
    final unvisitedNear = <m.Point>[];
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final nx = playerPos.x + dx;
        final ny = playerPos.y + dy;
        if (nx >= 0 && ny >= 0 && nx < _dungeon.width && ny < _dungeon.height) {
          if (!visited.contains('$nx,$ny')) {
            unvisitedNear.add(m.Point(nx, ny));
          }
        }
      }
    }

    if (unvisitedNear.isNotEmpty) {
      final revealed = unvisitedNear.take(3).toList();
      setState(() {
        for (final p in revealed) {
          visited.add('${p.x},${p.y}');
        }
      });
      AudioService.instance.playTap();
      final msg = '${pet.name} darts forward into the shadows, sniffing the stone floor and scouting the corridor ahead. It reveals ${revealed.length} hidden tiles!';
      _appendDmNarration(msg);
      _broadcastTvState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ ${pet.name} scouted and revealed ${revealed.length} tiles!'),
          backgroundColor: const Color(0xFF1E3A2F),
        ),
      );
    } else {
      final msg = '${pet.name} returns to your side and confirms the immediate perimeter is fully secured.';
      _appendDmNarration(msg);
    }
  }

  void _appendDmNarration(String text) {
    setState(() {
      chat.add({
        'role': 'dm',
        'text': text,
      });
    });
    TvCastService.instance.broadcastNarration('Dungeon Master', text);
    _refreshSmartSuggestions();
  }

  void _runCompanionAutonomousBehavior() {
    if (!mounted || _isTraversing || _isGenerating) return;
    final campaign = ref.read(campaignProvider);
    if (campaign == null || campaign.party.length <= 1) return;

    final rng = Random();
    final companionIndex = 1 + rng.nextInt(campaign.party.length - 1);
    final companion = campaign.party[companionIndex];
    final currentPos = companion.position ?? campaign.partyPosition;

    if (rng.nextDouble() < 0.55) {
      final candidates = <m.Point>[
        m.Point(currentPos.x + 1, currentPos.y),
        m.Point(currentPos.x - 1, currentPos.y),
        m.Point(currentPos.x, currentPos.y + 1),
        m.Point(currentPos.x, currentPos.y - 1),
      ].where((p) {
        if (!_isWalkableTile(p.x, p.y)) return false;
        return (p.x - playerPos.x).abs() <= 2 && (p.y - playerPos.y).abs() <= 2;
      }).toList();

      if (candidates.isNotEmpty) {
        final nextTile = candidates[rng.nextInt(candidates.length)];
        setState(() {
          companion.position = Point(nextTile.x, nextTile.y);
          visited.add('${nextTile.x},${nextTile.y}');
          campaign.visitedTiles.add('${nextTile.x},${nextTile.y}');
        });

        final nearbyProp = _props.where((p) => (p.pos.x - nextTile.x).abs() + (p.pos.y - nextTile.y).abs() <= 1).firstOrNull;
        if (nearbyProp != null) {
          final remark = _getPropObservation(nearbyProp, companion);
          _showCompanionSpeechBubble(companion.characterId, remark);
        }
      }
    } else {
      final banter = _getCompanionBanter(companion);
      _showCompanionSpeechBubble(companion.characterId, banter);
    }
  }

  void _showCompanionSpeechBubble(String characterId, String text) {
    if (!mounted) return;
    setState(() {
      _companionSpeechBubbles[characterId] = text;
    });
    _companionSpeechTimer?.cancel();
    _companionSpeechTimer = Timer(const Duration(milliseconds: 3800), () {
      if (mounted) {
        setState(() {
          _companionSpeechBubbles.remove(characterId);
        });
      }
    });
  }

  String _getPropObservation(MapProp prop, PartyMemberStatus companion) {
    final asset = prop.asset.toLowerCase();
    if (asset.contains('bookshelf') || asset.contains('lectern')) {
      return 'Fascinating runes on this parchment...';
    } else if (asset.contains('chest')) {
      return 'An iron coffer! Checking for triggers...';
    } else if (asset.contains('altar')) {
      return 'I feel divine warmth radiating here.';
    } else if (asset.contains('brazier') || asset.contains('torch')) {
      return 'The flames hold the dark at bay.';
    } else if (asset.contains('statue')) {
      return 'Stalwart sentinel of stone.';
    } else if (asset.contains('crystals')) {
      return 'Resonating with planar mana!';
    } else if (asset.contains('crates')) {
      return 'Munitions left by previous delves.';
    }
    return 'Inspecting the stonework closely.';
  }

  String _getCompanionBanter(PartyMemberStatus companion) {
    final race = companion.raceLabel.toLowerCase();
    final role = companion.classLabel.toLowerCase();
    final rng = Random();

    if (race.contains('dwarf')) {
      const dwarfBanter = [
        'Solid dwarven flagstones beneath our feet.',
        'Keep an eye on the roof vaults.',
        'My shield arm is ready for whatever stalks here.',
        'Smell that mineral draft? Hollow passage nearby.',
      ];
      return dwarfBanter[rng.nextInt(dwarfBanter.length)];
    } else if (race.contains('elf')) {
      const elfBanter = [
        'Faint ethereal whispers ride the subterranean air.',
        'My bow is strung and eager.',
        'Ancient elven enchantments linger in the mortar.',
        'Careful, the shadow geometry shifts ahead.',
      ];
      return elfBanter[rng.nextInt(elfBanter.length)];
    } else if (race.contains('half') || role.contains('rogue')) {
      const rogueBanter = [
        'Quiet footsteps... listen for tripwires.',
        'I have a feeling there\'s loot nearby.',
        'Watching the blind corners!',
        'No lock can keep us out for long.',
      ];
      return rogueBanter[rng.nextInt(rogueBanter.length)];
    } else if (role.contains('paladin') || role.contains('cleric')) {
      const holyBanter = [
        'May the sacred light preserve us in this crypt.',
        'Stand stalwart, victory is assured.',
        'Evil retreats before our unity.',
        'I shall guard our flank.',
      ];
      return holyBanter[rng.nextInt(holyBanter.length)];
    } else {
      const generalBanter = [
        'Stay sharp, friend.',
        'Covering the rear corridor!',
        'We make a formidable company.',
        'What lies beyond that doorway?',
      ];
      return generalBanter[rng.nextInt(generalBanter.length)];
    }
  }

  void _showCompanionInteractionSheet(PartyMemberStatus member) {
    AudioService.instance.playTap();
    final chars = ref.read(savedCharactersProvider);
    final charsById = {for (final c in chars) c.id: c};
    final portrait = _portraitForMember(member, charsById);
    final hpFactor = (member.hp / max(1, member.maxHp)).clamp(0.0, 1.0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF131122),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(color: ArcaneTheme.secondary.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ArcaneTheme.secondary, width: 2),
                    boxShadow: [
                      BoxShadow(color: ArcaneTheme.secondary.withValues(alpha: 0.4), blurRadius: 10),
                    ],
                    image: DecorationImage(image: AssetImage(portrait), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        '${member.raceLabel} • ${member.classLabel} (AC ${member.armorClass})',
                        style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600, color: ArcaneTheme.secondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('VITALITY', style: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white70)),
                    Text('${member.hp} / ${member.maxHp} HP', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: hpFactor > 0.35 ? const Color(0xFF3DD68C) : Colors.redAccent)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: hpFactor,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(hpFactor > 0.35 ? const Color(0xFF3DD68C) : Colors.redAccent),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
            if (member.persona.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  member.persona,
                  style: GoogleFonts.spectral(fontSize: 12.5, fontStyle: FontStyle.italic, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('TACTICAL PARTY COMMANDS', style: GoogleFonts.cinzel(fontSize: 11, fontWeight: FontWeight.w800, color: ArcaneTheme.secondary, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArcaneTheme.surfaceElevated,
                      foregroundColor: Colors.white,
                      side: BorderSide(color: ArcaneTheme.secondary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.explore_rounded, size: 16, color: ArcaneTheme.secondary),
                    label: const Text('Scout Ahead', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _companionScoutAhead(member);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArcaneTheme.surfaceElevated,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3DD68C)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF3DD68C)),
                    label: const Text('Guard Vanguard', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _companionGuardVanguard(member);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArcaneTheme.surfaceElevated,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFFFB300)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFFFFB300)),
                    label: const Text('Inspect Chamber', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _companionInspectChamber(member);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArcaneTheme.primary.withValues(alpha: 0.35),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: ArcaneTheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.amberAccent),
                    label: const Text('Banter / Chat', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _mentionMember(member.name);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _companionScoutAhead(PartyMemberStatus member) {
    AudioService.instance.playTap();
    final unvisited = <m.Point>[];

    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final nx = playerPos.x + dx;
        final ny = playerPos.y + dy;
        if (nx >= 0 && ny >= 0 && nx < _dungeon.width && ny < _dungeon.height) {
          if (!visited.contains('$nx,$ny') && _isWalkableTile(nx, ny)) {
            unvisited.add(m.Point(nx, ny));
          }
        }
      }
    }

    if (unvisited.isNotEmpty) {
      final target = unvisited.first;
      setState(() {
        member.position = Point(target.x, target.y);
        for (final p in unvisited.take(3)) {
          visited.add('${p.x},${p.y}');
        }
      });
      _showCompanionSpeechBubble(member.characterId, 'Path cleared ahead!');
      _appendDmNarration('${member.name} darts forward to scout the corridor, charting ${min(3, unvisited.length)} unexplored tiles ahead!');
    } else {
      _showCompanionSpeechBubble(member.characterId, 'Perimeter is secure!');
    }
  }

  void _companionGuardVanguard(PartyMemberStatus member) {
    AudioService.instance.playSuccess();
    setState(() {
      member.position = Point(playerPos.x, playerPos.y);
    });
    _showCompanionSpeechBubble(member.characterId, 'Shield raised! Holding the line.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${member.name} assumes a protective vanguard stance (+2 AC defense)!', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A2F),
        duration: const Duration(seconds: 2),
      ),
    );
    _send('I order ${member.name} to form a defensive vanguard beside me.');
  }

  void _companionInspectChamber(PartyMemberStatus member) {
    AudioService.instance.playTap();
    final nearbyProp = _props.where((p) => (p.pos.x - playerPos.x).abs() + (p.pos.y - playerPos.y).abs() <= 3).firstOrNull;
    if (nearbyProp != null) {
      setState(() {
        member.position = Point(nearbyProp.pos.x, nearbyProp.pos.y);
      });
      final text = _getPropObservation(nearbyProp, member);
      _showCompanionSpeechBubble(member.characterId, text);
      _appendDmNarration('${member.name} walks over to inspect the ${nearbyProp.name ?? "object"} closely: "$text"');
    } else {
      _showCompanionSpeechBubble(member.characterId, 'Searching the flagstones for traps...');
      _appendDmNarration('${member.name} sweeps the stonework, confirming no immediate threats.');
    }
  }

  void _checkSidequestProgression({m.Point? atPos, String? eventType}) {
    final campaign = ref.read(campaignProvider);
    if (campaign == null || campaign.sidequests.isEmpty) return;
    final pos = atPos ?? playerPos;

    for (final sq in campaign.sidequests) {
      if (sq.isCompleted) continue;
      bool completed = false;

      if (sq.id == 'sq_altar_relic') {
        final dist = (pos.x - sq.targetTile.x).abs() + (pos.y - sq.targetTile.y).abs();
        final nearAltar = _props.any((p) => (p.asset.contains('altar') || p.asset.contains('pillar')) && (p.pos.x - pos.x).abs() + (p.pos.y - pos.y).abs() <= 1);
        if (dist <= 1 || nearAltar) {
          completed = true;
        }
      } else if (sq.id == 'sq_crypt_scavenge') {
        if (eventType == 'loot' || _props.any((p) => p.asset.contains('chest_open'))) {
          completed = true;
        }
      } else if (sq.id == 'sq_beast_cull') {
        if (campaign.defeatedEnemies.length >= 2 || eventType == 'enemy_slain') {
          completed = true;
        }
      } else if (sq.id == 'sq_cartographer') {
        if (visited.length >= 25 || _discoveredRoomIds.length >= 2) {
          completed = true;
        }
      }

      if (completed) {
        sq.isCompleted = true;
        ref.read(campaignProvider.notifier).completeSidequest(sq.id);
        if (sq.rewardItem != null && campaign.party.isNotEmpty) {
          ref.read(campaignProvider.notifier).addItem(campaign.party.first.characterId, sq.rewardItem!);
        }
        AudioService.instance.playSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('SIDEQUEST COMPLETED: ${sq.title.toUpperCase()}!', style: GoogleFonts.cinzel(fontWeight: FontWeight.w800, color: Colors.amberAccent, fontSize: 12.5)),
                      Text('Objective Achieved: ${sq.objective}\nReward Claimed: ${sq.rewardDescription}', style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E2638),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _appendDmNarration('✨ SIDEQUEST COMPLETED! The party accomplishes "${sq.title}": ${sq.objective}. Claimed reward: ${sq.rewardDescription}!');
        _broadcastTvState();
        break;
      }
    }
  }

  List<SidequestMarker> _getSidequestMarkers(CampaignState? campaign) {
    if (campaign == null || campaign.sidequests.isEmpty) return const [];
    return [
      for (final sq in campaign.sidequests)
        if (!sq.isCompleted)
          SidequestMarker(
            pos: m.Point(sq.targetTile.x, sq.targetTile.y),
            title: sq.title,
            icon: sq.category == 'combat' ? '⚔️' : (sq.category == 'puzzle' ? '✨' : '📜'),
            onTap: () {
              AudioService.instance.playTap();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('📜 ${sq.title}: ${sq.objective} (Reward: ${sq.rewardDescription})', style: GoogleFonts.ibmPlexSans()),
                  backgroundColor: const Color(0xFF1F2433),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
    ];
  }

  Widget _buildSmartAiSuggestionsBar() {
    if (_smartSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.psychology_rounded, size: 13, color: Color(0xFF80D8FF)),
                const SizedBox(width: 5),
                Text(
                  'SMART AI SUGGESTIONS',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: const Color(0xFF80D8FF),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: _smartSuggestions.map((sug) {
                final color = switch (sug.type) {
                  SuggestionType.combat => Colors.redAccent,
                  SuggestionType.exploration => ArcaneTheme.secondary,
                  SuggestionType.pet => const Color(0xFF69F0AE),
                  SuggestionType.survival => Colors.tealAccent,
                  SuggestionType.dialogue => Colors.purpleAccent,
                };

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ActionChip(
                    avatar: Text(sug.icon, style: const TextStyle(fontSize: 12)),
                    label: Text(
                      sug.label,
                      style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    backgroundColor: ArcaneTheme.surfaceElevated,
                    side: BorderSide(color: color.withValues(alpha: 0.6), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    onPressed: () {
                      AudioService.instance.playTap();
                      _send(sug.text);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showTvCastSheet() {
    AudioService.instance.playTap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TvCastSheet(
        isCompanionMode: _isTvCompanionMode,
        onToggleCompanionMode: (enabled) {
          setState(() {
            _isTvCompanionMode = enabled;
          });
          _broadcastTvState();
        },
      ),
    );
  }

  Future<void> _toggleVoiceListening() async {
    if (_isVoiceListening) {
      await VoiceTranscriptionService.instance.stopListening();
      setState(() {
        _isVoiceListening = false;
        _voiceStatusText = '';
      });
      return;
    }

    final available = await VoiceTranscriptionService.instance.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speech recognition is not available or microphone permission was not granted.', style: GoogleFonts.ibmPlexSans()),
          backgroundColor: ArcaneTheme.tertiary,
        ),
      );
      return;
    }

    AudioService.instance.playSuccess();
    setState(() {
      _isVoiceListening = true;
      _voiceStatusText = 'Listening... Speak your command or narrative';
    });

    await VoiceTranscriptionService.instance.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _voiceStatusText = words;
          _inputController.text = words;
        });

        if (isFinal && words.trim().isNotEmpty) {
          _handleVoiceCommandCommit(words);
        }
      },
      onSoundLevel: (level) {
        if (mounted) setState(() => _voiceSoundLevel = level);
      },
    );
  }

  void _handleVoiceCommandCommit(String words) {
    setState(() {
      _isVoiceListening = false;
      _voiceStatusText = '';
    });
    final intent = VoiceTranscriptionService.parseIntent(words);
    switch (intent.type) {
      case VoiceCommandType.attack:
        _performAttackAction();
        break;
      case VoiceCommandType.search:
        _performSearchAction();
        break;
      case VoiceCommandType.castSpell:
        if (intent.spellName != null) {
          _send('I cast ${intent.spellName}!');
        } else {
          _showSpellPicker();
        }
        break;
      case VoiceCommandType.shortRest:
        _performShortRest();
        break;
      case VoiceCommandType.tactics:
        _showCompanionTactics();
        break;
      case VoiceCommandType.codex:
        _showExplorationCodex();
        break;
      case VoiceCommandType.minimap:
        _showMinimap();
        break;
      case VoiceCommandType.narration:
        _send(intent.rawText);
        break;
    }
  }

  Widget _buildVoiceStatusBanner() {
    if (!_isVoiceListening && _voiceStatusText.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Pulse(
            duration: Duration(milliseconds: 800),
            child: Icon(Icons.mic_rounded, color: Colors.redAccent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _voiceStatusText.isNotEmpty ? _voiceStatusText : 'Listening... speak your action or narrative',
              style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              VoiceTranscriptionService.instance.stopListening();
              setState(() {
                _isVoiceListening = false;
                _voiceStatusText = '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTvCompanionHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF181B28), Color(0xFF10121A)],
        ),
        border: Border(bottom: BorderSide(color: ArcaneTheme.secondary.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3DD68C).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3DD68C).withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.tv_rounded, color: Color(0xFF3DD68C), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('TV CAST ACTIVE', style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(width: 6),
                    Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF3DD68C))),
                  ],
                ),
                Text('Streaming 3D Map to Big Screen', style: GoogleFonts.ibmPlexSans(fontSize: 10.5, color: ArcaneTheme.secondary)),
              ],
            ),
          ),
          // Directional controls for moving on TV
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DpadMiniBtn(icon: Icons.keyboard_arrow_left_rounded, onTap: () => _move(-1, 0)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DpadMiniBtn(icon: Icons.keyboard_arrow_up_rounded, onTap: () => _move(0, -1)),
                  _DpadMiniBtn(icon: Icons.keyboard_arrow_down_rounded, onTap: () => _move(0, 1)),
                ],
              ),
              _DpadMiniBtn(icon: Icons.keyboard_arrow_right_rounded, onTap: () => _move(1, 0)),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.fullscreen_exit_rounded, size: 22, color: Colors.white70),
                tooltip: 'Show Map on Phone',
                onPressed: () => setState(() => _isTvCompanionMode = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExplorationCodex({int initialTab = 0}) {
    AudioService.instance.playTap();
    final campaign = ref.read(campaignProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DefaultTabController(
        length: 2,
        initialIndex: initialTab,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.explore_rounded, color: ArcaneTheme.secondary, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'DUNGEON EXPLORATION & QUESTS',
                            style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: ArcaneTheme.secondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '${_discoveredRoomIds.length}/${_dungeon.rooms.length} Charted',
                      style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                indicatorColor: ArcaneTheme.secondary,
                labelColor: ArcaneTheme.secondary,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.meeting_room_rounded, size: 16),
                    text: 'CHAMBERS (${_discoveredRoomIds.length}/${_dungeon.rooms.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.assignment_rounded, size: 16),
                    text: 'SIDEQUESTS (${campaign?.sidequests.where((s) => s.isCompleted).length ?? 0}/${campaign?.sidequests.length ?? 0})',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Chambers
                    ListView.separated(
                      itemCount: _dungeon.rooms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final room = _dungeon.rooms[idx];
                        final isDiscovered = _discoveredRoomIds.contains(room.id);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDiscovered ? const Color(0xFF1C2232) : Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDiscovered ? ArcaneTheme.secondary.withValues(alpha: 0.5) : Colors.white10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isDiscovered ? room.type.icon : '❓', style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDiscovered ? room.name : 'Uncharted Crypt Chamber',
                                      style: GoogleFonts.cinzel(fontSize: 13, fontWeight: FontWeight.w700, color: isDiscovered ? Colors.white : Colors.white38),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isDiscovered ? room.description : 'Veiled in damp dungeon gloom. Delve further into the corridors to chart this chamber.',
                                      style: GoogleFonts.ibmPlexSans(fontSize: 11, color: isDiscovered ? Colors.white70 : Colors.white30),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Tab 2: Sidequests
                    if (campaign == null || campaign.sidequests.isEmpty)
                      Center(
                        child: Text(
                          'No active sidequests discovered in this dungeon yet.',
                          style: GoogleFonts.ibmPlexSans(color: Colors.white54),
                        ),
                      )
                    else
                      ListView.separated(
                        itemCount: campaign.sidequests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final sq = campaign.sidequests[idx];
                          final isDone = sq.isCompleted;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDone ? const Color(0xFF16251E) : const Color(0xFF1C2232),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDone ? const Color(0xFF3DD68C).withValues(alpha: 0.6) : ArcaneTheme.secondary.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      sq.category == 'combat' ? '⚔️' : (sq.category == 'puzzle' ? '✨' : '📜'),
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sq.title,
                                            style: GoogleFonts.cinzel(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isDone ? const Color(0xFF3DD68C) : Colors.white,
                                            ),
                                          ),
                                          Text(
                                            'TYPE: ${sq.category.toUpperCase()} • TARGET: (${sq.targetTile.x}, ${sq.targetTile.y})',
                                            style: GoogleFonts.ibmPlexSans(
                                              fontSize: 9.5,
                                              letterSpacing: 0.5,
                                              color: isDone ? Colors.white60 : ArcaneTheme.secondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDone ? const Color(0xFF3DD68C).withValues(alpha: 0.2) : Colors.amberAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDone ? const Color(0xFF3DD68C) : Colors.amberAccent,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        isDone ? 'COMPLETED' : 'ACTIVE',
                                        style: GoogleFonts.cinzel(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isDone ? const Color(0xFF3DD68C) : Colors.amberAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  sq.objective,
                                  style: GoogleFonts.ibmPlexSans(fontSize: 11.5, color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.card_giftcard_rounded, size: 14, color: Colors.amberAccent),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Reward: ${sq.rewardDescription}',
                                        style: GoogleFonts.ibmPlexSans(fontSize: 10.5, color: Colors.amberAccent),
                                      ),
                                    ),
                                    if (!isDone)
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          backgroundColor: ArcaneTheme.secondary.withValues(alpha: 0.15),
                                        ),
                                        icon: const Icon(Icons.my_location_rounded, size: 12, color: ArcaneTheme.secondary),
                                        label: Text('Locate', style: GoogleFonts.cinzel(fontSize: 10, color: ArcaneTheme.secondary, fontWeight: FontWeight.w700)),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _recenterOnTile(m.Point(sq.targetTile.x, sq.targetTile.y));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Focusing map on sidequest: ${sq.title}', style: GoogleFonts.ibmPlexSans()),
                                              duration: const Duration(seconds: 2),
                                              backgroundColor: const Color(0xFF1E2638),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCampaignJournal() {
    final campaign = ref.read(campaignProvider);
    if (campaign == null) return;
    AudioService.instance.playTap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CampaignJournalSheet(
        campaign: campaign,
        onLongRestCompleted: (restoredHp) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Long rest completed. Full party HP restored! (+$restoredHp HP)', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, color: Colors.white)),
              backgroundColor: const Color(0xFF3DD68C),
              duration: const Duration(seconds: 3),
            ),
          );
        },
        onRestNarration: (narration) {
          _send(narration);
        },
      ),
    );
  }

  void _triggerCampfireBanter() {
    final campaign = ref.read(campaignProvider);
    final chars = ref.read(savedCharactersProvider);
    final pet = _getActivePet(campaign, chars);
    AudioService.instance.playSend();
    if (campaign == null || campaign.party.length < 2) {
      if (pet != null && pet.id != 'none') {
        _send('I take a rest by the glowing campfire. Beside me, ${pet.name} curls up close, resting peacefully in the warmth as I hone my blade.');
      } else {
        _send('I take a rest by the glowing campfire, honing my blade and reflecting on the quest.');
      }
      return;
    }
    final companions = campaign.party.skip(1).toList();
    final speaker = companions[Random().nextInt(companions.length)];
    final petText = (pet != null && pet.id != 'none')
        ? ' Beside the crackling flames, ${pet.name} naps peacefully, keeping quiet watch.'
        : '';
    _send('The party rests around the warm campfire glow. ${speaker.name} breaks the silence, sharing a tale of battle and a word of counsel for the journey ahead...$petText');
  }

  void _showDescentDialog() {
    final depth = ref.read(campaignProvider)?.worldFlags['dungeonDepth'] as int? ?? 1;
    final nextDepth = depth + 1;
    AudioService.instance.playTap();
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ArcaneTheme.primary.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.stairs_rounded, color: ArcaneTheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DESCENT STAIRCASE', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Stone steps spiral downward into Dungeon Depth $nextDepth.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('A frigid draft ascends from the dark abyss below. Do you lead the party down?', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Stay on this Floor'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                label: Text('Descend to Depth $nextDepth'),
                style: ElevatedButton.styleFrom(backgroundColor: ArcaneTheme.primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  _regenerate();
                  _send('The party descends the spiral stone stairs into Dungeon Depth $nextDepth...');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _performShortRest() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArcaneTheme.surface,
        title: Text('SHORT REST', style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Take an hour to bind wounds and regroup by the torchlight. Each party member rolls a hit die to restore HP.', style: GoogleFonts.ibmPlexSans(color: ArcaneTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ArcaneTheme.primary),
            onPressed: () {
              Navigator.pop(ctx);
              final campaign = ref.read(campaignProvider);
              if (campaign != null) {
                final rng = Random();
                for (final member in campaign.party) {
                  final heal = rng.nextInt(6) + 3;
                  ref.read(campaignProvider.notifier).updateHp(member.characterId, heal);
                }
                AudioService.instance.playSuccess();
                _send('The party takes a short rest, patching wounds and regaining stamina.');
              }
            },
            child: const Text('Rest & Heal'),
          ),
        ],
      ),
    );
  }

  void _showSpellPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CAST SPELL', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Choose an arcane or divine incantation.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
          const SizedBox(height: 12),
          _SpellTile(name: 'Magic Missile', desc: 'Three glowing darts of force unerringly strike foes (3d4+3).', icon: Icons.auto_awesome_rounded, color: ArcaneTheme.primary, onTap: () {
            Navigator.pop(ctx);
            _send('I cast Magic Missile at the nearest threat!');
          }),
          _SpellTile(name: 'Cure Wounds', desc: 'Touch a creature to channel positive energy, healing 1d8 + WIS.', icon: Icons.healing_rounded, color: const Color(0xFF3DD68C), onTap: () {
            Navigator.pop(ctx);
            final campaign = ref.read(campaignProvider);
            if (campaign != null && campaign.party.isNotEmpty) {
              ref.read(campaignProvider.notifier).updateHp(campaign.party.first.characterId, 7);
            }
            AudioService.instance.playSuccess();
            _send('I cast Cure Wounds to restore vitality!');
          }),
          _SpellTile(name: 'Sacred Flame', desc: 'Radiance descends from above to burn enemy armor (1d8).', icon: Icons.local_fire_department_rounded, color: ArcaneTheme.secondary, onTap: () {
            Navigator.pop(ctx);
            _send('I cast Sacred Flame to engulf the enemy in celestial fire!');
          }),
        ]),
      ),
    );
  }

  void _showCompanionTactics() {
    final campaign = ref.read(campaignProvider);
    if (campaign == null || campaign.party.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No AI companions in party yet.', style: GoogleFonts.ibmPlexSans()), backgroundColor: ArcaneTheme.tertiary),
      );
      return;
    }

    final companions = campaign.party.skip(1).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PARTY TACTICS', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Issue orders to your AI companions.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
          const SizedBox(height: 12),
          for (final comp in companions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: ArcaneTheme.cardDecoration(),
                child: ListTile(
                  title: Text(comp.name, style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  subtitle: Text('${comp.raceLabel} ${comp.classLabel} • HP ${comp.hp}/${comp.maxHp}', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.secondary)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ArcaneTheme.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showOrderOptionsForCompanion(comp);
                  },
                ),
              ),
            ),
        ]),
      ),
    );
  }

  void _showOrderOptionsForCompanion(PartyMemberStatus comp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcaneTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TACTICAL ORDER: ${comp.name.toUpperCase()}', style: GoogleFonts.cinzel(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.shield_rounded, color: ArcaneTheme.primary),
            title: const Text('Take point and raise defense'),
            onTap: () {
              Navigator.pop(ctx);
              _send('@${comp.name} Take the front line and raise your shield to protect the party!');
            },
          ),
          ListTile(
            leading: const Icon(Icons.flash_on_rounded, color: Colors.redAccent),
            title: const Text('Target priority: Strike nearest hostile foe'),
            onTap: () {
              Navigator.pop(ctx);
              _send('@${comp.name} Focus your next attack on the closest enemy threat!');
            },
          ),
          ListTile(
            leading: const Icon(Icons.search_rounded, color: ArcaneTheme.secondary),
            title: const Text('Scout ahead and check for traps'),
            onTap: () {
              Navigator.pop(ctx);
              _send('@${comp.name} Scout ahead carefully and see what lies in the next room.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.healing_rounded, color: Color(0xFF3DD68C)),
            title: const Text('Administer first aid to the party'),
            onTap: () {
              Navigator.pop(ctx);
              _send('@${comp.name} Tend to our wounded companions and prepare healing supplies.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_stories_rounded, color: Color(0xFF29B6F6)),
            title: const Text('Analyze surroundings and share tactical insight'),
            onTap: () {
              Navigator.pop(ctx);
              _send('@${comp.name} What do your keen eyes make of this chamber?');
            },
          ),
        ]),
      ),
    );
  }

  void _showMinimap() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArcaneTheme.surface,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('DUNGEON MAP', style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: ArcaneTheme.textMuted), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 280,
          height: 280,
          child: CustomPaint(
            size: const Size(280, 280),
            painter: _DungeonMinimapPainter(
              dungeon: _dungeon,
              playerPos: playerPos,
              visited: visited,
            ),
          ),
        ),
      ),
    );
  }

  void _regenerate() {
    final campaign = ref.read(campaignProvider);
    final newSeed = Random().nextInt(1 << 30);
    final newDungeon = DungeonGenerator().generate(seed: newSeed, width: 34, height: 34);
    final entry = Point(newDungeon.entryPoint.x, newDungeon.entryPoint.y);
    setState(() {
      _adHocSeed = newSeed;
      _seed = newSeed;
      _dungeon = newDungeon;
      playerPos = m.Point(entry.x, entry.y);
      visited = {'${entry.x},${entry.y}'};
      _mapInitialized = true;
      _mapCentered = false;
      chat.clear();
      _props = generateDungeonProps(newDungeon);
      final floorEnemies = generateDungeonEnemies(newDungeon, excluding: {
        for (final p in _props) '${p.pos.x},${p.pos.y}',
      });
      final floorRoaming = generateDungeonRoamingNpcs(newDungeon, excluding: {
        for (final p in _props) '${p.pos.x},${p.pos.y}',
        for (final e in floorEnemies) '${e.pos.x},${e.pos.y}',
      });
      _npcs = [...floorEnemies, ...floorRoaming];
      _openedDoors.clear();
      _activePath = null;
      _discoveredRoomIds.clear();
      for (final r in newDungeon.rooms) {
        if (r.contains(playerPos)) {
          _discoveredRoomIds.add(r.id);
        }
      }
    });
    if (campaign != null) {
      ref.read(campaignProvider.notifier).newFloor(newSeed: newSeed, entryPoint: entry);
      final updated = ref.read(campaignProvider);
      if (widget.sessionId != null && _isMultiplayerHost == true && updated != null) {
        SessionRepository.instance.pushState(widget.sessionId!, updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = ref.watch(campaignProvider);
    final chars = ref.watch(savedCharactersProvider);
    _ensureMapForCampaign(campaign);
    _ensureChatForCampaign(campaign);
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
          IconButton(
            icon: Icon(
              TvCastService.instance.isRunning ? Icons.tv_rounded : Icons.cast_rounded,
              color: TvCastService.instance.isRunning ? const Color(0xFF3DD68C) : Colors.white,
              size: 20,
            ),
            tooltip: 'TV Cast & Big Screen',
            onPressed: _showTvCastSheet,
          ),
          IconButton(icon: const Icon(Icons.explore_rounded, size: 20), onPressed: _showExplorationCodex, tooltip: 'Exploration Codex'),
          IconButton(icon: const Icon(Icons.auto_stories_rounded, size: 20), onPressed: _showCampaignJournal, tooltip: 'Campaign Codex & Rest'),
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
        if (_isTvCompanionMode)
          _buildTvCompanionHud()
        else
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
                  child: Transform(
                    transform: _is3dPerspective
                        ? (Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateX(0.22))
                        : Matrix4.identity(),
                    alignment: FractionalOffset.center,
                    child: IsoMapView(
                      dungeon: _dungeon,
                      playerPos: playerPos,
                      visited: visited,
                      partyMembers: _partyVisuals(campaign, chars),
                      environment: campaign?.mapEnvironment ?? 'dungeon',
                      npcs: _npcs,
                      animals: _animals,
                      props: _props,
                      activePet: _getActivePet(campaign, chars),
                      openedDoors: _openedDoors,
                      activePath: _activePath,
                      targetWaypoint: _targetWaypoint,
                      sidequestMarkers: _getSidequestMarkers(campaign),
                      onPartyMemberTap: (visual) {
                        final member = campaign?.party.where((m) => m.name == visual.name).firstOrNull;
                        if (member != null) _showCompanionInteractionSheet(member);
                      },
                      onTileTap: _handleTileTap,
                      onPropTap: _handlePropTap,
                      onNpcTap: _handleNpcTap,
                      onAnimalTap: _showAnimalInteractionDialog,
                      onPetTap: _showPetInteractionDialog,
                    ),
                  ),
                ),
              );
            }),
            // Live Quest Objective HUD overlay
            if (campaign != null && (campaign.questLog.isNotEmpty || campaign.sidequests.isNotEmpty))
              Positioned(
                top: 8,
                left: 8,
                right: 64, // leave clearance for right-side map buttons
                child: Builder(builder: (context) {
                  final activeBeat = campaign.questLog.where((q) => q.status == 'active').firstOrNull;
                  final beatIdx = activeBeat != null ? campaign.questLog.indexOf(activeBeat) + 1 : campaign.questLog.length;
                  final title = activeBeat?.title ?? 'Dungeon Cleansed';
                  final completedSq = campaign.sidequests.where((s) => s.isCompleted).length;
                  final totalSq = campaign.sidequests.length;
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF10121A).withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.6)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showExplorationCodex(initialTab: 0),
                              borderRadius: BorderRadius.horizontal(
                                left: const Radius.circular(10),
                                right: totalSq == 0 ? const Radius.circular(10) : Radius.zero,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.explore_rounded, size: 16, color: ArcaneTheme.secondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'QUEST BEAT $beatIdx/${campaign.questLog.length}',
                                            style: GoogleFonts.cinzel(fontSize: 9.5, fontWeight: FontWeight.w800, color: ArcaneTheme.secondary, letterSpacing: 0.8),
                                          ),
                                          Text(
                                            title,
                                            style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ArcaneTheme.secondary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        '${_discoveredRoomIds.length}/${_dungeon.rooms.length}',
                                        style: GoogleFonts.ibmPlexSans(fontSize: 9.5, color: ArcaneTheme.secondary, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (totalSq > 0) ...[
                          Container(width: 1, height: 26, color: ArcaneTheme.secondary.withValues(alpha: 0.3)),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showExplorationCodex(initialTab: 1),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('📜', style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$completedSq/$totalSq SQ',
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: completedSq == totalSq ? const Color(0xFF3DD68C) : ArcaneTheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
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
                const SizedBox(height: 6),
                _MapBtn(
                  icon: _is3dPerspective ? Icons.view_in_ar_rounded : Icons.layers_rounded,
                  color: _is3dPerspective ? ArcaneTheme.secondary : null,
                  onTap: () {
                    setState(() => _is3dPerspective = !_is3dPerspective);
                    AudioService.instance.playTap();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_is3dPerspective ? '3D Cinematic Perspective enabled' : 'Standard 2.5D Isometric view restored'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF1B1429),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                _MapBtn(icon: Icons.map_rounded, onTap: _showMinimap),
                const SizedBox(height: 6),
                _MapBtn(icon: Icons.auto_stories_rounded, onTap: _showCampaignJournal),
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
                child: Text('Tap tile/D-pad to move • Tap chest to loot', style: GoogleFonts.ibmPlexSans(fontSize: 10, color: Colors.white70)),
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
                final hpFrac = m.maxHp <= 0 ? 0.0 : (m.hp / m.maxHp).clamp(0.0, 1.0);
                final hpColor = hpFrac > 0.5 ? ArcaneTheme.secondary : (hpFrac > 0.2 ? Colors.orange : Colors.redAccent);
                return PressableScale(
                  onTap: isLead ? null : () => _showCompanionInteractionSheet(m),
                  onLongPress: () => showInventorySheet(context, ref, m),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: isLead ? 17 : 14,
                    backgroundColor: (isLead ? ArcaneTheme.primary : ArcaneTheme.secondary).withOpacity(0.18),
                    backgroundImage: asset != null ? AssetImage(asset) : null,
                    child: asset == null ? Icon(Icons.person_rounded, size: isLead ? 16 : 13, color: isLead ? ArcaneTheme.primary : ArcaneTheme.secondary) : null,
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      width: isLead ? 34 : 28,
                      height: 3,
                      child: LinearProgressIndicator(value: hpFrac, backgroundColor: Colors.white.withOpacity(0.12), valueColor: AlwaysStoppedAnimation(hpColor)),
                    ),
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

        // On-Device ML Kit & Tactical AI Smart Suggestions
        _buildSmartAiSuggestionsBar(),

        // Quick actions — match Stitch: Attack, Talk, Inspect, Roll Die
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _QuickAction(icon: Icons.flash_on_rounded, label: 'Attack', color: ArcaneTheme.tertiary, onTap: _performAttackAction),
              _QuickAction(icon: Icons.search_rounded, label: 'Search', color: ArcaneTheme.secondary, onTap: _performSearchAction),
              _QuickAction(icon: Icons.auto_awesome_rounded, label: 'Cast Spell', color: ArcaneTheme.primary, onTap: _showSpellPicker),
              _QuickAction(icon: Icons.shield_rounded, label: 'Tactics', color: const Color(0xFF29B6F6), onTap: _showCompanionTactics),
              _QuickAction(icon: Icons.bedtime_rounded, label: 'Short Rest', color: const Color(0xFF3DD68C), onTap: _performShortRest),
              _QuickAction(icon: Icons.fireplace_rounded, label: 'Campfire', color: Colors.deepOrangeAccent, onTap: _triggerCampfireBanter),
              _QuickAction(icon: Icons.chat_bubble_rounded, label: 'Talk', color: ArcaneTheme.primary, onTap: () => _send('I speak to whoever is nearby.')),
              _QuickAction(icon: Icons.casino_rounded, label: 'Roll Die', color: ArcaneTheme.secondary, onTap: () => _send('I roll a d20 ability check.')),
            ]),
          ),
        ),

        // Input bar — flush with keyboard, no gap
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 8 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: ArcaneTheme.surface, border: Border(top: BorderSide(color: ArcaneTheme.border))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildVoiceStatusBanner(),
              Row(children: [
                PressableScale(
                  onTap: _toggleVoiceListening,
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _isVoiceListening ? Colors.redAccent.withValues(alpha: 0.2) : ArcaneTheme.surfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isVoiceListening ? Colors.redAccent : Colors.white12,
                        width: _isVoiceListening ? 2 : 1,
                      ),
                      boxShadow: [
                        if (_isVoiceListening)
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: (_voiceSoundLevel.clamp(0.0, 10.0) / 10.0).clamp(0.2, 0.8)),
                            blurRadius: 10,
                          ),
                      ],
                    ),
                    child: Icon(
                      _isVoiceListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isVoiceListening ? Colors.redAccent : Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _isVoiceListening ? 'Listening... speak now' : 'Speak to the party, or tap someone to address them...',
                      filled: true,
                      fillColor: ArcaneTheme.surfaceElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
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
                    decoration: BoxDecoration(
                      color: ArcaneTheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: ArcaneTheme.primary.withValues(alpha: 0.3), blurRadius: 8)],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _isGenerating
                          ? const Padding(key: ValueKey('spinner'), padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, key: ValueKey('send'), color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ]),
            ],
          ),
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
  final Color? color;
  const _MapBtn({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color != null ? color!.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color ?? Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: 16, color: color ?? Colors.white),
      ),
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

class _DungeonMinimapPainter extends CustomPainter {
  final m.DungeonMap dungeon;
  final m.Point playerPos;
  final Set<String> visited;

  _DungeonMinimapPainter({
    required this.dungeon,
    required this.playerPos,
    required this.visited,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / dungeon.width;
    final cellH = size.height / dungeon.height;

    final wallPaint = Paint()..color = const Color(0xFF140F22);
    final visitedFloorPaint = Paint()..color = const Color(0xFF4A3B69);
    final unvisitedFloorPaint = Paint()..color = const Color(0xFF221A38);
    final doorPaint = Paint()..color = const Color(0xFF3DD68C);
    final playerPaint = Paint()..color = const Color(0xFFFFB300);

    for (var y = 0; y < dungeon.height; y++) {
      for (var x = 0; x < dungeon.width; x++) {
        final rect = Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5);
        final tile = dungeon.tileAt(x, y);
        final isVisited = visited.contains('$x,$y');

        if (tile == m.TileType.wall) {
          canvas.drawRect(rect, wallPaint);
        } else if (tile == m.TileType.door) {
          canvas.drawRect(rect, doorPaint);
        } else if (isVisited) {
          canvas.drawRect(rect, visitedFloorPaint);
        } else {
          canvas.drawRect(rect, unvisitedFloorPaint);
        }
      }
    }

    // Draw player dot
    final px = (playerPos.x + 0.5) * cellW;
    final py = (playerPos.y + 0.5) * cellH;
    canvas.drawCircle(Offset(px, py), cellW * 1.6, playerPaint);
    canvas.drawCircle(Offset(px, py), cellW * 2.8, Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _DungeonMinimapPainter oldDelegate) => true;
}

class _SpellTile extends StatelessWidget {
  final String name;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SpellTile({required this.name, required this.desc, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: ArcaneTheme.cardDecoration(),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, color: Colors.white)),
              Text(desc, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: ArcaneTheme.textSecondary)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _DpadMiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DpadMiniBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2433),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
