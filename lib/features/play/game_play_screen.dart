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
import '../../services/audio_service.dart';
import '../../services/session_repository.dart';
import '../../services/tts_service.dart';
import '../../widgets/fx.dart';
import '../../widgets/campaign_journal_sheet.dart';
import '../../widgets/inventory_sheet.dart';
import '../../widgets/tactical_combat_sheet.dart';
import '../../widgets/npc_interaction_sheet.dart';
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
  m.Point? _targetWaypoint;
  List<m.Point>? _activePath;
  final Set<String> _openedDoors = {};
  final Set<String> _traps = {};
  final Set<String> _revealedTraps = {};
  bool _isTraversing = false;
  List<Map<String, String>> chat = [];
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
      for (final e in allEnemies) {
        if (defeated.contains(e.id)) {
          _props.add(MapProp(pos: e.pos, asset: 'assets/tiles/prop_bones.png'));
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
        // A one-on-one exchange with a specific companion (mention.addressedTo)
        // stays theirs alone — no unrelated beat butting in right after.
        await _maybeCompanionBeat(campaign, engine, skip: mention.addressedTo != null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        chat.add({
          'role': 'dm',
          'text': 'Torchlight flickers against the ancient stones as you steady your grip on your weapon and advance.',
        });
        _isGenerating = false;
        _streamingText = '';
      });
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

  bool _isWalkableTile(int x, int y) {
    if (x < 0 || y < 0 || x >= _dungeon.width || y >= _dungeon.height) return false;
    final tile = _dungeon.tileAt(x, y);
    if (tile == m.TileType.wall || tile == m.TileType.water) return false;
    if (tile == m.TileType.door && !_openedDoors.contains('$x,$y')) return false;
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

  void _move(int dx, int dy) {
    final nx = playerPos.x + dx;
    final ny = playerPos.y + dy;
    if (nx < 0 || ny < 0 || nx >= _dungeon.width || ny >= _dungeon.height) return;
    if (_dungeon.tileAt(nx, ny) == m.TileType.wall || _dungeon.tileAt(nx, ny) == m.TileType.water) return;
    setState(() {
      playerPos = m.Point(nx, ny);
      visited.add('$nx,$ny');
    });
    ref.read(campaignProvider.notifier).moveTo(Point(nx, ny));
    _recenterOnPlayer();
    _roamNpcs();

    // Check if player triggered an undiscovered trap
    final posKey = '$nx,$ny';
    if (_traps.contains(posKey) && !_revealedTraps.contains(posKey)) {
      _traps.remove(posKey);
      _revealedTraps.add(posKey);
      _props.add(MapProp(pos: m.Point(nx, ny), asset: 'assets/tiles/prop_rubble.png'));
      AudioService.instance.playError();
      final trapDmg = Random().nextInt(4) + 2;
      final campaign = ref.read(campaignProvider);
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

    final isDoor = _dungeon.tileAt(target.x, target.y) == m.TileType.door;
    final isDoorClosed = isDoor && !_openedDoors.contains('${target.x},${target.y}');
    final distToTarget = (playerPos.x - target.x).abs() + (playerPos.y - target.y).abs();

    if (isDoorClosed && distToTarget <= 1) {
      _showDoorInteractionDialog(target);
      return;
    }

    final path = m.findPath(_dungeon, playerPos, target, closedDoors: _closedDoors);
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tile unreachable or blocked by stone barrier', style: GoogleFonts.ibmPlexSans()),
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

        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
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
          final t1 = path[max(0, i - 1)];
          campaign.party[1].position = Point(t1.x, t1.y);
          if (campaign.party.length > 2 && i > 1) {
            final t2 = path[max(0, i - 2)];
            campaign.party[2].position = Point(t2.x, t2.y);
          }
        }
      });

      if (i % 2 == 0) {
        AudioService.instance.playTap();
      }

      // Check if stepped directly onto a concealed trap
      final stepKey = '${step.x},${step.y}';
      if (_traps.contains(stepKey) && !_revealedTraps.contains(stepKey)) {
        _traps.remove(stepKey);
        _revealedTraps.add(stepKey);
        _props.add(MapProp(pos: step, asset: 'assets/tiles/prop_rubble.png'));
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

      final tile = _dungeon.tileAt(playerPos.x, playerPos.y);
      final desc = tile == m.TileType.door ? 'through the doorway' : 'into the chamber';
      _send('I traverse the corridor $desc.');
    }
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
    final d20 = Random().nextInt(20) + 1;
    final total = d20 + 3; // +3 perception
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
          _props.add(MapProp(pos: m.Point(tx, ty), asset: 'assets/tiles/prop_rubble.png'));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perception [$total]: TRAP DETECTED! You spot a concealed tripwire at ($tx,$ty)! (Marked with rubble)', style: GoogleFonts.ibmPlexSans()),
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
            _props.add(MapProp(pos: stashSpot, asset: 'assets/tiles/prop_chest.png'));
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
          content: Text('Perception [$total]: SUCCESS! No hidden traps detected along the floor.', style: GoogleFonts.ibmPlexSans()),
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
    if (dist > 2) {
      _handleTileTap(prop.pos);
      return;
    }

    if (_dungeon.rooms.length > 1 && prop.pos.x == _dungeon.rooms.last.centerX && prop.pos.y == _dungeon.rooms.last.centerY) {
      _showDescentDialog();
    } else if (prop.asset.contains('pillar') && _dungeon.rooms.length > 2 && prop.pos.x == _dungeon.rooms[1].centerX && prop.pos.y == _dungeon.rooms[1].centerY) {
      _showAltarDialog(prop);
    } else if (prop.asset.contains('chest')) {
      _showLootChestDialog(prop);
    } else if (prop.asset.contains('torch')) {
      AudioService.instance.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Torchflare! The warm glow banishes the shadows.', style: GoogleFonts.ibmPlexSans()),
          backgroundColor: ArcaneTheme.primary,
          duration: const Duration(seconds: 1),
        ),
      );
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
    AudioService.instance.playSend();
    if (campaign == null || campaign.party.length < 2) {
      _send('I take a rest by the glowing torchlight, honing my blade and reflecting on the quest.');
      return;
    }
    final companions = campaign.party.skip(1).toList();
    final speaker = companions[Random().nextInt(companions.length)];
    _send('The party rests around the warm glow. ${speaker.name} breaks the silence, sharing a tale of battle and a word of counsel for the journey ahead...');
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
                    openedDoors: _openedDoors,
                    activePath: _activePath,
                    targetWaypoint: _targetWaypoint,
                    onTileTap: _handleTileTap,
                    onPropTap: _handlePropTap,
                    onNpcTap: _handleNpcTap,
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
                  onTap: isLead ? null : () => _mentionMember(m.name),
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
