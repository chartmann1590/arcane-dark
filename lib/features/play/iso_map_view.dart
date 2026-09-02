import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/map/tile_types.dart' as m;
import '../../widgets/fx.dart';
import 'tavern_populator.dart';

/// A pseudo-isometric dungeon renderer: the same square tile textures the
/// game already ships get warped into diamonds and laid out on a proper
/// isometric grid, and wall tiles grow a solid extruded block underneath
/// their diamond top so the maze actually reads as having height instead of
/// being a flat painted floor. No new art required — same assets, a real
/// projection.
class IsoMapView extends StatelessWidget {
  final m.DungeonMap dungeon;
  final m.Point playerPos;
  final Set<String> visited;
  // Every current party member (heroes + recruited AI companions), lead
  // first — each gets their own token clustered at the party's shared
  // position, instead of one token standing in for the whole group.
  final List<PartyMemberVisual> partyMembers;
  // 'tavern' or 'dungeon' — which tile art this map uses. A campaign that
  // starts at a tavern/inn/outpost renders warm wood-and-timber tiles
  // instead of the generic stone dungeon set (see CampaignState.environmentFor).
  final String environment;
  // Fixed NPCs and furniture scattered across an indoor map — see
  // tavern_populator.dart. Empty for dungeon-environment maps.
  final List<MapNpc> npcs;
  final List<MapProp> props;
  final void Function(MapNpc npc)? onNpcTap;

  static const double tileW = 64;
  static const double tileH = 32;
  static const double wallRise = 26;

  const IsoMapView({
    super.key,
    required this.dungeon,
    required this.playerPos,
    required this.visited,
    this.partyMembers = const [],
    this.environment = 'dungeon',
    this.npcs = const [],
    this.props = const [],
    this.onNpcTap,
  });

  Offset _project(int x, int y, double originX, double originY) {
    return Offset(originX + (x - y) * tileW / 2, originY + (x + y) * tileH / 2);
  }

  @override
  Widget build(BuildContext context) {
    final originX = dungeon.height * tileW / 2;
    const originY = tileH / 2;
    final totalWidth = (dungeon.width + dungeon.height) * tileW / 2 + tileW;
    final totalHeight = (dungeon.width + dungeon.height) * tileH / 2 + wallRise + tileH * 2;

    // Painter's algorithm: draw back-to-front (increasing x+y) so nearer
    // tiles' risers correctly occlude the tiles behind them.
    final coords = <m.Point>[
      for (var y = 0; y < dungeon.height; y++)
        for (var x = 0; x < dungeon.width; x++) m.Point(x, y),
    ]..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final p in coords) _buildTile(p.x, p.y, originX, originY),
          // Props, NPCs, and the player are their own top-level overlay layer
          // — NOT nested inside each tile's own tightly-constrained Positioned
          // box. Flutter's hit-testing checks a parent's *own* declared size
          // before it ever looks at children, so a token painted above its
          // tiny tile box via Clip.none renders correctly but is silently
          // untappable when nested that way. Positioning tokens directly on
          // the full (much larger) canvas here sidesteps that entirely.
          for (final prop in props) _buildProp(prop, originX, originY),
          for (final npc in npcs) _buildNpc(npc, originX, originY),
          for (var i = 0; i < partyMembers.length; i++) _buildPartyMember(partyMembers[i], i, originX, originY),
          if (partyMembers.isEmpty) _buildPartyMember(const PartyMemberVisual(name: 'You', portraitAsset: null), 0, originX, originY),
        ],
      ),
    );
  }

  Widget _buildTile(int x, int y, double originX, double originY) {
    final tile = dungeon.tileAt(x, y);
    final isPlayer = playerPos.x == x && playerPos.y == y;
    final isVisited = visited.contains('$x,$y');
    final isWall = tile == m.TileType.wall;
    final isDoor = tile == m.TileType.door;
    final raised = isWall || isDoor;
    final riseH = isWall ? wallRise : (isDoor ? wallRise * 0.4 : 0.0);

    final isTavern = environment == 'tavern';
    final tileAsset = switch (tile) {
      m.TileType.wall => isTavern ? 'assets/tiles/wall_tavern.png' : 'assets/tiles/wall.png',
      m.TileType.floor => isTavern ? 'assets/tiles/floor_tavern.png' : 'assets/tiles/floor.png',
      m.TileType.door => 'assets/tiles/door.png',
      m.TileType.water => 'assets/tiles/water.png',
      m.TileType.forest => 'assets/tiles/forest.png',
      m.TileType.mountain => 'assets/tiles/mountain.png',
      m.TileType.plains => 'assets/tiles/plains.png',
    };

    // Walls/doors/water always render (you can see the dungeon's shape from
    // a lit room), but floor tiles you haven't stepped into stay hidden —
    // this is what actually creates the "exploring fog of war" feel.
    // Indoor tavern rooms skip fog entirely: you're standing in a small, lit
    // room you can already see, not crawling a dark dungeon one step at a time.
    final canFog = tile == m.TileType.floor && !isTavern;
    final origin = _project(x, y, originX, originY);

    return Positioned(
      left: origin.dx,
      top: origin.dy - riseH,
      width: tileW,
      height: tileH + riseH,
      child: Stack(clipBehavior: Clip.none, children: [
        if (raised)
          Positioned(
            left: 0,
            top: tileH / 2,
            child: CustomPaint(size: Size(tileW, riseH + tileH / 2), painter: _IsoRiserPainter(isDoor: isDoor, isTavern: isTavern)),
          ),
        Positioned(
          left: 0,
          top: 0,
          child: SizedBox(
            width: tileW,
            height: tileH,
            child: ClipPath(
              clipper: _DiamondClipper(),
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(tileAsset, fit: BoxFit.fill),
                if (canFog && !isVisited)
                  Container(color: Colors.black)
                else if (canFog && isVisited && !isPlayer)
                  Container(color: Colors.black.withOpacity(0.38))
                else if (!canFog)
                  Container(color: Colors.black.withOpacity(0.15)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildProp(MapProp prop, double originX, double originY) {
    final origin = _project(prop.pos.x, prop.pos.y, originX, originY);
    return Positioned(
      left: origin.dx + tileW / 2 - 24,
      top: origin.dy - 22,
      child: IgnorePointer(child: Image.asset(prop.asset, width: 48, height: 48, fit: BoxFit.contain)),
    );
  }

  Widget _buildNpc(MapNpc npc, double originX, double originY) {
    final origin = _project(npc.pos.x, npc.pos.y, originX, originY);
    return Positioned(
      left: origin.dx + tileW / 2 - 23,
      top: origin.dy - 24,
      // Listener + onPointerDown, not GestureDetector.onTap — inside an
      // InteractiveViewer, its own pan/scale recognizer competes for the
      // gesture arena and can win the race before a tap ever resolves.
      // Listener routes raw pointer events outside the arena entirely.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onNpcTap == null ? null : (_) => onNpcTap!(npc),
        child: Padding(padding: const EdgeInsets.all(8), child: _NpcToken(npc: npc)),
      ),
    );
  }

  // Small fan-out so up to several party members clustered on the same tile
  // each render as their own visible, distinct token instead of stacking
  // exactly on top of one another.
  static const _clusterOffsets = [
    Offset(0, 0),
    Offset(-16, -6),
    Offset(16, -6),
    Offset(-16, 8),
    Offset(16, 8),
    Offset(0, -16),
  ];

  Widget _buildPartyMember(PartyMemberVisual member, int index, double originX, double originY) {
    // The lead always stands exactly at playerPos; companions render at
    // their own independently-tracked tile if they have one (see
    // GamePlayScreen._wanderCompanions / move_companion), falling back to
    // the shared position until they've moved on their own at least once.
    final pos = member.pos ?? playerPos;
    final tile = dungeon.tileAt(pos.x, pos.y);
    final riseH = tile == m.TileType.wall ? wallRise : (tile == m.TileType.door ? wallRise * 0.4 : 0.0);
    final origin = _project(pos.x, pos.y, originX, originY);
    // Only fan out with a cluster offset when actually sharing a tile with
    // the lead — a companion who's wandered to their own tile renders
    // dead-center on it instead of nudged sideways.
    final sharingTile = pos.x == playerPos.x && pos.y == playerPos.y;
    final offset = sharingTile ? _clusterOffsets[index % _clusterOffsets.length] : Offset.zero;
    final isLead = index == 0;
    final token = _PartyToken(portraitAsset: member.portraitAsset, isLead: isLead);
    return Positioned(
      left: origin.dx + tileW / 2 - 16 + offset.dx,
      top: origin.dy - riseH - 14 + offset.dy,
      child: isLead ? Pulse(child: token) : token,
    );
  }
}

class _NpcToken extends StatelessWidget {
  final MapNpc npc;
  const _NpcToken({required this.npc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ArcaneTheme.secondary, width: 2),
        boxShadow: [BoxShadow(color: ArcaneTheme.secondary.withOpacity(0.5), blurRadius: 8)],
        image: DecorationImage(image: AssetImage(npc.portraitAsset), fit: BoxFit.cover),
      ),
    );
  }
}

class _PartyToken extends StatelessWidget {
  final String? portraitAsset;
  final bool isLead;
  const _PartyToken({this.portraitAsset, this.isLead = true});

  @override
  Widget build(BuildContext context) {
    // The lead (the player) gets the bigger, glowing, pulsing token; every
    // other party member/companion is a real but visually secondary token —
    // still their own person, not lost in the crowd.
    final size = isLead ? 32.0 : 26.0;
    final color = isLead ? ArcaneTheme.primary : ArcaneTheme.secondary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: isLead ? 2 : 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(isLead ? 0.6 : 0.4), blurRadius: isLead ? 10 : 6, spreadRadius: isLead ? 1 : 0)],
        image: portraitAsset != null ? DecorationImage(image: AssetImage(portraitAsset!), fit: BoxFit.cover) : null,
        color: portraitAsset == null ? color : null,
      ),
      child: portraitAsset == null ? Icon(Icons.person_rounded, size: isLead ? 18 : 14, color: Colors.white) : null,
    );
  }
}

/// One party member's map appearance and independent position (null =
/// hasn't moved on their own yet, render at the shared party position).
class PartyMemberVisual {
  final String name;
  final String? portraitAsset;
  final m.Point? pos;
  const PartyMemberVisual({required this.name, this.portraitAsset, this.pos});
}

/// Clips a rectangle down to the diamond inscribed within it — the standard
/// trick for turning a square (or squashed) texture into an isometric tile
/// face with zero new art.
class _DiamondClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// The extruded block beneath a wall/door diamond — two shaded parallelogram
/// faces (left catching less light than right) so the tile reads as a solid
/// raised block instead of a flat painted square, entirely via solid fills
/// (no texture needed for the side faces).
class _IsoRiserPainter extends CustomPainter {
  final bool isDoor;
  final bool isTavern;
  const _IsoRiserPainter({required this.isDoor, this.isTavern = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rise = h - IsoMapView.tileH / 2;
    final base = isDoor ? const Color(0xFF4A3B2A) : (isTavern ? const Color(0xFF3A2A1A) : const Color(0xFF2A2438));
    final leftPaint = Paint()..color = Color.lerp(base, Colors.black, 0.35)!;
    final rightPaint = Paint()..color = Color.lerp(base, Colors.black, 0.1)!;

    // Left face: from the diamond's left vertex down to the bottom vertex.
    final left = Path()
      ..moveTo(0, IsoMapView.tileH / 4)
      ..lineTo(w / 2, IsoMapView.tileH / 2)
      ..lineTo(w / 2, IsoMapView.tileH / 2 + rise)
      ..lineTo(0, IsoMapView.tileH / 4 + rise)
      ..close();
    // Right face: from the diamond's bottom vertex to the right vertex.
    final right = Path()
      ..moveTo(w / 2, IsoMapView.tileH / 2)
      ..lineTo(w, IsoMapView.tileH / 4)
      ..lineTo(w, IsoMapView.tileH / 4 + rise)
      ..lineTo(w / 2, IsoMapView.tileH / 2 + rise)
      ..close();

    canvas.drawPath(left, leftPaint);
    canvas.drawPath(right, rightPaint);
  }

  @override
  bool shouldRepaint(covariant _IsoRiserPainter oldDelegate) => oldDelegate.isDoor != isDoor || oldDelegate.isTavern != isTavern;
}
