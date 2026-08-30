import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../domain/map/dungeon_generator.dart';
import '../../domain/map/tile_types.dart' as m;
import '../../providers/campaign_provider.dart';
import '../../providers/character_provider.dart';
import '../../domain/campaign_seed.dart';
import '../../domain/dm_turn_engine.dart';
import '../../services/audio_service.dart';

class GamePlayScreen extends ConsumerStatefulWidget {
  const GamePlayScreen({super.key});
  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  final _inputController = TextEditingController();
  bool _isGenerating = false;
  String _streamingText = '';
  late m.DungeonMap _dungeon;
  late int _seed;
  Set<String> visited = {};
  m.Point playerPos = const m.Point(5, 5);
  List<Map<String, String>> chat = [];

  @override
  void initState() {
    super.initState();
    _seed = Random().nextInt(1 << 30);
    _dungeon = DungeonGenerator().generate(seed: _seed, width: 18, height: 18);
    playerPos = m.Point(_dungeon.entryPoint.x, _dungeon.entryPoint.y);
    visited = {'${playerPos.x},${playerPos.y}'};
    // Load persisted campaign if any
    Future.microtask(() => ref.read(campaignProvider.notifier).loadPersisted());
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _isGenerating) return;
    AudioService.instance.playSend();
    final campaign = ref.read(campaignProvider);
    setState(() {
      chat.add({'role': 'player', 'text': text});
      _isGenerating = true;
      _streamingText = '';
    });
    _inputController.clear();

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
        setState(() {
          chat.add({'role': 'dm', 'text': _streamingText.trim()});
          _isGenerating = false;
          _streamingText = '';
        });
      } else {
        final engine = ref.read(dmEngineProvider);
        final result = await engine.takeTurn(
          playerInput: text,
          state: campaign,
          onToken: (chunk) {
            if (!mounted) return;
            setState(() => _streamingText += chunk);
          },
        );
        if (result.hadRoll) AudioService.instance.playDiceRoll();
        setState(() {
          chat.add({'role': 'dm', 'text': result.narration, 'roll': _rollBadge(result)});
          _isGenerating = false;
          _streamingText = '';
          ref.read(campaignProvider.notifier).load(campaign); // refresh UI
        });
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
      return '${c.success ? "SUCCESS" : "FAIL"} (${c.ability} d20:${c.roll}+${c.modifier}=${c.total} vs DC ${c.dc})';
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
    ref.read(campaignProvider.notifier).moveTo(m.Point(nx, ny) as dynamic);
    // auto describe
    _send('I move to the next area.');
  }

  void _regenerate() {
    setState(() {
      _seed = Random().nextInt(1 << 30);
      _dungeon = DungeonGenerator().generate(seed: _seed, width: 18, height: 18);
      playerPos = m.Point(_dungeon.entryPoint.x, _dungeon.entryPoint.y);
      visited = {'${playerPos.x},${playerPos.y}'};
      chat.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final campaign = ref.watch(campaignProvider);
    final chars = ref.watch(savedCharactersProvider);

    return Scaffold(
      backgroundColor: ArcaneTheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(campaign?.seed.title.toUpperCase() ?? 'ADVENTURE', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
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
              PopupMenuItem(value: 'new_campaign', child: Text('New Campaign', style: GoogleFonts.manrope(color: Colors.white))),
              PopupMenuItem(value: 'seed', child: Text('Seed: $_seed', style: GoogleFonts.manrope(color: ArcaneTheme.textSecondary, fontSize: 12))),
            ],
          ),
        ],
      ),
      body: Column(children: [
        // Map viewport — matches Stitch Main Gameplay Screen dungeon tile look
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFF0B0A12), border: Border(bottom: BorderSide(color: ArcaneTheme.border))),
          child: Stack(children: [
            // Grid
            Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _dungeon.width, crossAxisSpacing: 2, mainAxisSpacing: 2),
                itemCount: _dungeon.width * _dungeon.height,
                itemBuilder: (c, idx) {
                  final x = idx % _dungeon.width;
                  final y = idx ~/ _dungeon.width;
                  final tile = _dungeon.tileAt(x, y);
                  final isPlayer = playerPos.x == x && playerPos.y == y;
                  final isVisited = visited.contains('$x,$y');

                  final tileAsset = switch (tile) {
                    m.TileType.wall => 'assets/tiles/wall.png',
                    m.TileType.floor => 'assets/tiles/floor.png',
                    m.TileType.door => 'assets/tiles/door.png',
                    m.TileType.water => 'assets/tiles/water.png',
                    m.TileType.forest => 'assets/tiles/forest.png',
                    m.TileType.mountain => 'assets/tiles/mountain.png',
                    m.TileType.plains => 'assets/tiles/plains.png',
                  };

                  // Walls/doors/water always render (you can see the dungeon's shape from
                  // a lit room), but floor tiles you haven't stepped into stay hidden —
                  // this is what actually creates the "exploring fog of war" feel.
                  final canFog = tile == m.TileType.floor;

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
                      Image.asset(tileAsset, fit: BoxFit.cover),
                      if (canFog && !isVisited)
                        Container(color: Colors.black)
                      else if (canFog && isVisited && !isPlayer)
                        Container(color: Colors.black.withOpacity(0.38))
                      else if (!canFog)
                        Container(color: Colors.black.withOpacity(0.15)),
                      if (isPlayer)
                        DecoratedBox(
                          decoration: BoxDecoration(border: Border.all(color: ArcaneTheme.primary, width: 1.5), boxShadow: [BoxShadow(color: ArcaneTheme.primary.withOpacity(0.5), blurRadius: 8)]),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(color: ArcaneTheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                            child: const Icon(Icons.person_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                    ]),
                  );
                },
              ),
            ),
            // Controls overlay
            Positioned(
              right: 8,
              top: 8,
              child: Column(children: [
                _MapBtn(icon: Icons.add_rounded, onTap: _regenerate),
                const SizedBox(height: 6),
                _MapBtn(icon: Icons.remove_rounded, onTap: () {}),
                const SizedBox(height: 6),
                _MapBtn(icon: Icons.my_location_rounded, onTap: () {}),
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
                child: Text('Seed $_seed • ${_dungeon.rooms.length} rooms • Tap arrows to move', style: GoogleFonts.manrope(fontSize: 10, color: Colors.white70)),
              ),
            ),
          ]),
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
                        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: ArcaneTheme.primary.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.auto_stories_rounded, color: ArcaneTheme.primary, size: 28)),
                        const SizedBox(height: 14),
                        Text(campaign == null ? 'The dungeon awaits your first words...' : campaign.currentSceneDescription, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 14, color: ArcaneTheme.textSecondary, height: 1.5)),
                        const SizedBox(height: 10),
                        Text('Try: "I inspect the altar" or "I attack the shadow"', style: GoogleFonts.manrope(fontSize: 12, color: ArcaneTheme.textMuted, fontStyle: FontStyle.italic)),
                      ]),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      if (campaign != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ArcaneTheme.border)),
                          child: Text(campaign.currentSceneDescription, style: GoogleFonts.manrope(fontSize: 13, color: ArcaneTheme.textSecondary, height: 1.5, fontStyle: FontStyle.italic)),
                        ),
                      ...chat.map((m) {
                        final isPlayer = m['role'] == 'player';
                        return Align(
                          alignment: isPlayer ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: isPlayer ? ArcaneTheme.primary : ArcaneTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(14).copyWith(bottomRight: isPlayer ? const Radius.circular(4) : null, bottomLeft: !isPlayer ? const Radius.circular(4) : null),
                              border: Border.all(color: isPlayer ? ArcaneTheme.primary : ArcaneTheme.border),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m['text']!, style: GoogleFonts.manrope(fontSize: 13.5, color: isPlayer ? Colors.white : ArcaneTheme.textPrimary, height: 1.45)),
                              if (m['roll'] != null && m['roll']!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: ArcaneTheme.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text('🎲 ${m['roll']}', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: ArcaneTheme.secondary)),
                                ),
                            ]),
                          ),
                        );
                      }),
                      if (_isGenerating)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: ArcaneTheme.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: ArcaneTheme.primary.withOpacity(0.3))),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ArcaneTheme.primary)),
                              const SizedBox(width: 10),
                              Flexible(child: Text(_streamingText.isEmpty ? 'The Dungeon Master is weaving your fate...' : _streamingText, style: GoogleFonts.manrope(fontSize: 13, color: ArcaneTheme.textSecondary, height: 1.4))),
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
        SafeArea(
          top: false,
          bottom: true,
          minimum: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(color: ArcaneTheme.surface, border: Border(top: BorderSide(color: ArcaneTheme.border))),
            child: Row(children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(hintText: 'What do you do?', filled: true, fillColor: ArcaneTheme.surfaceElevated, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                onSubmitted: _send,
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _send(_inputController.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: ArcaneTheme.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: ArcaneTheme.primary.withOpacity(0.3), blurRadius: 8)]),
                child: _isGenerating ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: Colors.white70)));
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: ArcaneTheme.surfaceElevated, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
          child: Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}
