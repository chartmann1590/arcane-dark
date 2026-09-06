import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/map/tile_types.dart' as m;
import '../../domain/pet_companion.dart';
import '../../widgets/fx.dart';
import 'tavern_populator.dart';

/// A pseudo-isometric dungeon renderer with dynamic torchlight, atmospheric fog,
/// interactive objects, and tap-to-move waypoint visualization.
class IsoMapView extends StatelessWidget {
  final m.DungeonMap dungeon;
  final m.Point playerPos;
  final Set<String> visited;
  final List<PartyMemberVisual> partyMembers;
  final String environment;
  final List<MapNpc> npcs;
  final List<MapAnimal> animals;
  final List<MapProp> props;
  final PetCompanion? activePet;
  final Set<String> openedDoors;
  final List<m.Point>? activePath;
  final m.Point? targetWaypoint;
  final void Function(m.Point tile)? onTileTap;
  final void Function(MapNpc npc)? onNpcTap;
  final void Function(MapAnimal animal)? onAnimalTap;
  final void Function(MapProp prop)? onPropTap;

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
    this.animals = const [],
    this.props = const [],
    this.activePet,
    this.openedDoors = const {},
    this.activePath,
    this.targetWaypoint,
    this.onTileTap,
    this.onNpcTap,
    this.onAnimalTap,
    this.onPropTap,
  });

  Offset _project(int x, int y, double originX, double originY) {
    return Offset(originX + (x - y) * tileW / 2, originY + (x + y) * tileH / 2);
  }

  List<m.Point> get _torchPositions =>
      props.where((p) => p.asset.contains('torch') || p.asset.contains('campfire') || p.asset.contains('brazier')).map((p) => p.pos).toList();

  double _lightIntensityAt(int x, int y, List<m.Point> torches) {
    final dPx = (playerPos.x - x).toDouble();
    final dPy = (playerPos.y - y).toDouble();
    final distPlayer = sqrt(dPx * dPx + dPy * dPy);

    double minDist = distPlayer;
    for (final t in torches) {
      final dTx = (t.x - x).toDouble();
      final dTy = (t.y - y).toDouble();
      final distTorch = sqrt(dTx * dTx + dTy * dTy);
      if (distTorch < minDist) minDist = distTorch;
    }

    if (minDist > 2.8) return 0.0;
    return (2.8 - minDist) / 2.8;
  }

  @override
  Widget build(BuildContext context) {
    final originX = dungeon.height * tileW / 2;
    const originY = tileH / 2;
    final totalWidth = (dungeon.width + dungeon.height) * tileW / 2 + tileW;
    final totalHeight = (dungeon.width + dungeon.height) * tileH / 2 + wallRise + tileH * 2;
    final torches = _torchPositions;

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
          for (final p in coords) _buildTile(p.x, p.y, originX, originY, torches),
          for (final prop in props) _buildProp(prop, originX, originY),
          for (final animal in animals) _buildAnimal(animal, originX, originY),
          for (final npc in npcs) _buildNpc(npc, originX, originY),
          for (var i = 0; i < partyMembers.length; i++) _buildPartyMember(partyMembers[i], i, originX, originY),
          if (partyMembers.isEmpty) _buildPartyMember(const PartyMemberVisual(name: 'You', portraitAsset: null), 0, originX, originY),
          if (activePet != null && activePet!.id != 'none') _buildPetCompanion(activePet!, originX, originY),
        ],
      ),
    );
  }

  Widget _buildTile(int x, int y, double originX, double originY, List<m.Point> torches) {
    final tile = dungeon.tileAt(x, y);
    final isPlayer = playerPos.x == x && playerPos.y == y;
    final isVisited = visited.contains('$x,$y');
    final isWall = tile == m.TileType.wall;
    final isDoor = tile == m.TileType.door;
    final isDoorOpen = isDoor && openedDoors.contains('$x,$y');
    final raised = isWall || (isDoor && !isDoorOpen);
    final riseH = isWall ? wallRise : (isDoor && !isDoorOpen ? wallRise * 0.4 : 0.0);

    final isTavern = environment == 'tavern';
    final tileAsset = switch (tile) {
      m.TileType.wall => isTavern ? 'assets/tiles/wall_tavern.png' : 'assets/tiles/wall.png',
      m.TileType.floor => isTavern ? 'assets/tiles/floor_tavern.png' : 'assets/tiles/floor.png',
      m.TileType.door => isDoorOpen ? 'assets/tiles/floor.png' : 'assets/tiles/door.png',
      m.TileType.water => 'assets/tiles/water.png',
      m.TileType.forest => 'assets/tiles/forest.png',
      m.TileType.mountain => 'assets/tiles/mountain.png',
      m.TileType.plains => 'assets/tiles/plains.png',
    };

    final canFog = (tile == m.TileType.floor || isDoorOpen) && !isTavern;
    final origin = _project(x, y, originX, originY);
    final lightIntensity = _lightIntensityAt(x, y, torches);
    final isTargetWaypoint = targetWaypoint != null && targetWaypoint!.x == x && targetWaypoint!.y == y;
    final isPathStep = activePath != null && activePath!.any((p) => p.x == x && p.y == y);

    Offset downPos = Offset.zero;

    return Positioned(
      left: origin.dx,
      top: origin.dy - riseH,
      width: tileW,
      height: tileH + riseH,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => downPos = e.position,
        onPointerUp: (e) {
          if ((e.position - downPos).distanceSquared < 400) {
            onTileTap?.call(m.Point(x, y));
          }
        },
        child: Stack(clipBehavior: Clip.none, children: [
          if (raised)
            Positioned(
              left: 0,
              top: tileH / 2,
              child: CustomPaint(
                size: Size(tileW, riseH + tileH / 2),
                painter: _IsoRiserPainter(
                  isDoor: isDoor && !isDoorOpen,
                  isTavern: isTavern,
                  torchGlow: lightIntensity,
                ),
              ),
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
                  if (canFog && !isVisited) ...[
                    if (lightIntensity > 0)
                      Container(color: const Color(0xFF15102A).withValues(alpha: (0.95 - lightIntensity * 0.35).clamp(0.0, 1.0)))
                    else
                      Container(color: const Color(0xFF0A0812)),
                  ] else if (canFog && isVisited) ...[
                    if (isPlayer)
                      Container(color: const Color(0xFFFFB300).withValues(alpha: 0.18))
                    else if (lightIntensity > 0)
                      Container(color: const Color(0xFFFF9800).withValues(alpha: (0.15 * lightIntensity).clamp(0.0, 1.0)))
                    else
                      Container(color: const Color(0xFF0D0A1A).withValues(alpha: 0.48)),
                  ] else if (!canFog) ...[
                    if (lightIntensity > 0)
                      Container(color: const Color(0xFFFFB300).withValues(alpha: (0.12 * lightIntensity).clamp(0.0, 1.0)))
                    else
                      Container(color: Colors.black.withValues(alpha: 0.15)),
                  ],
                  if (isPathStep && !isPlayer && !isTargetWaypoint)
                    Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ArcaneTheme.secondary.withValues(alpha: 0.65),
                          boxShadow: [
                            BoxShadow(color: ArcaneTheme.secondary.withValues(alpha: 0.5), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  if (isDoor && !isDoorOpen)
                    Center(
                      child: Icon(
                        Icons.meeting_room_rounded,
                        size: 14,
                        color: Colors.amber.withValues(alpha: 0.8),
                      ),
                    ),
                  if (isTargetWaypoint)
                    Container(
                      decoration: BoxDecoration(
                        color: ArcaneTheme.secondary.withValues(alpha: 0.35),
                        border: Border.all(color: ArcaneTheme.secondary, width: 2),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  bool _isFogged(m.Point pos) => environment != 'tavern' && !visited.contains('${pos.x},${pos.y}');

  Widget _buildProp(MapProp prop, double originX, double originY) {
    if (_isFogged(prop.pos)) return const SizedBox.shrink();
    final origin = _project(prop.pos.x, prop.pos.y, originX, originY);
    final isChest = prop.asset.contains('chest');
    final isTorch = prop.asset.contains('torch');
    final isCampfire = prop.asset.contains('campfire');
    final isBookshelf = prop.asset.contains('bookshelf');
    final isWeaponRack = prop.asset.contains('weapon_rack');
    final isAltar = prop.asset.contains('altar');
    final isRug = prop.asset.contains('rug');
    final isChair = prop.asset.contains('chair');

    Offset propDown = Offset.zero;

    Widget childWidget;
    if (isCampfire) {
      childWidget = const _CampfirePropWidget();
    } else if (isBookshelf) {
      childWidget = const _BookshelfPropWidget();
    } else if (isWeaponRack) {
      childWidget = const _WeaponRackPropWidget();
    } else if (isAltar) {
      childWidget = const _AltarPropWidget();
    } else if (isRug) {
      childWidget = const _RugPropWidget();
    } else if (isChair) {
      childWidget = const _ChairPropWidget();
    } else {
      childWidget = Image.asset(prop.asset, width: 48, height: 48, fit: BoxFit.contain);
    }

    return Positioned(
      left: origin.dx + tileW / 2 - 24,
      top: origin.dy - (isRug ? 10 : 22),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => propDown = e.position,
        onPointerUp: (e) {
          if ((e.position - propDown).distanceSquared < 400) {
            onPropTap?.call(prop);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (isTorch)
              Pulse(
                duration: const Duration(milliseconds: 1400),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.65),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            childWidget,
            if (isChest)
              Positioned(
                top: 4,
                right: 4,
                child: Pulse(
                  duration: const Duration(milliseconds: 1800),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: ArcaneTheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 10, color: Colors.black),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimal(MapAnimal animal, double originX, double originY) {
    if (_isFogged(animal.pos)) return const SizedBox.shrink();
    final origin = _project(animal.pos.x, animal.pos.y, originX, originY);
    final emoji = switch (animal.iconType) {
      'hound' => '🐕',
      'cat' => '🐈',
      'wolf' => '🐺',
      'owl' => '🦉',
      'fox' => '🦊',
      'bat' => '🦇',
      _ => '🐾',
    };

    return Positioned(
      left: origin.dx + tileW / 2 - 13,
      top: origin.dy - 12,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onAnimalTap == null ? null : (_) => onAnimalTap!(animal),
        child: Pulse(
          duration: const Duration(milliseconds: 2000),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1428),
              border: Border.all(color: const Color(0xFF3DD68C), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFF3DD68C).withValues(alpha: 0.4), blurRadius: 6),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPetCompanion(PetCompanion pet, double originX, double originY) {
    final origin = _project(playerPos.x, playerPos.y, originX, originY);
    return Positioned(
      left: origin.dx + tileW / 2 + 7,
      top: origin.dy - 6,
      child: Pulse(
        duration: const Duration(milliseconds: 1800),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A1423),
            border: Border.all(color: pet.color, width: 1.5),
            boxShadow: [
              BoxShadow(color: pet.color.withValues(alpha: 0.6), blurRadius: 8),
            ],
          ),
          child: Center(
            child: Text(
              pet.emoji,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNpc(MapNpc npc, double originX, double originY) {
    if (_isFogged(npc.pos)) return const SizedBox.shrink();
    final origin = _project(npc.pos.x, npc.pos.y, originX, originY);
    final token = Padding(padding: const EdgeInsets.all(8), child: _NpcToken(npc: npc));
    return Positioned(
      left: origin.dx + tileW / 2 - 23,
      top: origin.dy - (npc.isHostile ? 28 : 24),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onNpcTap == null ? null : (_) => onNpcTap!(npc),
        child: npc.isHostile ? Pulse(duration: const Duration(milliseconds: 1400), child: token) : token,
      ),
    );
  }

  static const _clusterOffsets = [
    Offset(0, 0),
    Offset(-5, -2),
    Offset(5, -2),
    Offset(-5, 2),
    Offset(5, 2),
  ];

  Widget _buildPartyMember(PartyMemberVisual member, int index, double originX, double originY) {
    final pos = member.pos ?? playerPos;
    final origin = _project(pos.x, pos.y, originX, originY);
    final sharingTile = pos.x == playerPos.x && pos.y == playerPos.y;
    Offset offset = sharingTile ? _clusterOffsets[index % _clusterOffsets.length] : Offset.zero;

    // Strict boundary adherence: ensure character is never pushed towards or over adjacent walls
    if (offset.dy < 0 && (dungeon.tileAt(pos.x, pos.y - 1) == m.TileType.wall || dungeon.tileAt(pos.x - 1, pos.y) == m.TileType.wall)) {
      offset = Offset(offset.dx, 0);
    }
    if (offset.dx < 0 && dungeon.tileAt(pos.x - 1, pos.y) == m.TileType.wall) {
      offset = Offset(0, offset.dy);
    }
    if (offset.dx > 0 && dungeon.tileAt(pos.x + 1, pos.y) == m.TileType.wall) {
      offset = Offset(0, offset.dy);
    }

    final isLead = index == 0;
    final token = _PartyToken(portraitAsset: member.portraitAsset, isLead: isLead);
    return Positioned(
      left: origin.dx + tileW / 2 - 16 + offset.dx,
      top: origin.dy - 14 + offset.dy,
      child: isLead ? Pulse(child: token) : token,
    );
  }
}

class _NpcToken extends StatelessWidget {
  final MapNpc npc;
  const _NpcToken({required this.npc});

  @override
  Widget build(BuildContext context) {
    final hpFactor = (npc.currentHp / max(1, npc.maxHp)).clamp(0.0, 1.0);
    final borderCol = npc.isHostile ? Colors.redAccent : ArcaneTheme.secondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (npc.isHostile) ...[
          Container(
            width: 28,
            height: 3.5,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.black, width: 0.5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: hpFactor,
              child: Container(
                decoration: BoxDecoration(
                  color: hpFactor > 0.4 ? Colors.redAccent : Colors.amberAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderCol, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: borderCol.withValues(alpha: npc.isHostile ? 0.7 : 0.5),
                    blurRadius: npc.isHostile ? 12 : 8,
                    spreadRadius: npc.isHostile ? 1 : 0,
                  ),
                ],
                image: DecorationImage(image: AssetImage(npc.portraitAsset), fit: BoxFit.cover),
              ),
            ),
            if (npc.isHostile)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.flash_on_rounded, size: 9, color: Colors.white),
                ),
              )
            else
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: ArcaneTheme.secondary, shape: BoxShape.circle),
                  child: const Icon(Icons.chat_bubble_rounded, size: 9, color: Colors.black),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PartyToken extends StatelessWidget {
  final String? portraitAsset;
  final bool isLead;
  const _PartyToken({this.portraitAsset, this.isLead = true});

  @override
  Widget build(BuildContext context) {
    final size = isLead ? 32.0 : 26.0;
    final color = isLead ? ArcaneTheme.primary : ArcaneTheme.secondary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: isLead ? 2 : 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: isLead ? 0.6 : 0.4), blurRadius: isLead ? 10 : 6, spreadRadius: isLead ? 1 : 0)],
        image: portraitAsset != null ? DecorationImage(image: AssetImage(portraitAsset!), fit: BoxFit.cover) : null,
        color: portraitAsset == null ? color : null,
      ),
      child: portraitAsset == null ? Icon(Icons.person_rounded, size: isLead ? 18 : 14, color: Colors.white) : null,
    );
  }
}

class PartyMemberVisual {
  final String name;
  final String? portraitAsset;
  final m.Point? pos;
  const PartyMemberVisual({required this.name, this.portraitAsset, this.pos});
}

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

class _IsoRiserPainter extends CustomPainter {
  final bool isDoor;
  final bool isTavern;
  final double torchGlow;
  const _IsoRiserPainter({required this.isDoor, this.isTavern = false, this.torchGlow = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rise = h - IsoMapView.tileH / 2;
    Color base = isDoor ? const Color(0xFF4A3B2A) : (isTavern ? const Color(0xFF3A2A1A) : const Color(0xFF2A2438));
    if (torchGlow > 0) {
      base = Color.lerp(base, const Color(0xFF5A3010), torchGlow * 0.45)!;
    }
    final leftPaint = Paint()..color = Color.lerp(base, Colors.black, 0.35)!;
    final rightPaint = Paint()..color = Color.lerp(base, Colors.black, 0.1)!;

    final left = Path()
      ..moveTo(0, IsoMapView.tileH / 4)
      ..lineTo(w / 2, IsoMapView.tileH / 2)
      ..lineTo(w / 2, IsoMapView.tileH / 2 + rise)
      ..lineTo(0, IsoMapView.tileH / 4 + rise)
      ..close();
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
  bool shouldRepaint(covariant _IsoRiserPainter oldDelegate) =>
      oldDelegate.isDoor != isDoor ||
      oldDelegate.isTavern != isTavern ||
      oldDelegate.torchGlow != torchGlow;
}

class _CampfirePropWidget extends StatelessWidget {
  const _CampfirePropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Pulse(
            duration: const Duration(milliseconds: 1200),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.7),
                    blurRadius: 20,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 32,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF374151),
              border: Border.all(color: const Color(0xFF6B7280), width: 1.5),
            ),
          ),
          Transform.rotate(
            angle: 0.6,
            child: Container(
              width: 22,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF4E342E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Transform.rotate(
            angle: -0.6,
            child: Container(
              width: 22,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3E2723),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Positioned(
            top: 6,
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 24,
              color: Color(0xFFFF9800),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookshelfPropWidget extends StatelessWidget {
  const _BookshelfPropWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF3E2723),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF5D4037), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(width: 4, height: 12, color: Colors.indigoAccent),
              Container(width: 5, height: 11, color: Colors.amberAccent),
              Container(width: 4, height: 13, color: Colors.deepOrangeAccent),
              Container(width: 5, height: 12, color: Colors.tealAccent),
            ],
          ),
          Container(height: 1.5, color: const Color(0xFF5D4037)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(width: 5, height: 12, color: Colors.purpleAccent),
              Container(width: 4, height: 13, color: Colors.cyanAccent),
              Container(width: 5, height: 11, color: Colors.redAccent),
              Container(width: 4, height: 12, color: Colors.lightGreenAccent),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeaponRackPropWidget extends StatelessWidget {
  const _WeaponRackPropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 30,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF2C241D),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF4A3E33), width: 1.5),
            ),
          ),
          const Positioned(
            child: Icon(Icons.shield_rounded, size: 18, color: Color(0xFF90A4AE)),
          ),
          Positioned(
            left: 4,
            top: 2,
            child: Transform.rotate(
              angle: 0.4,
              child: Container(width: 2, height: 28, color: Colors.amberAccent.shade100),
            ),
          ),
          Positioned(
            right: 4,
            top: 2,
            child: Transform.rotate(
              angle: -0.4,
              child: Container(width: 2, height: 28, color: Colors.cyanAccent.shade100),
            ),
          ),
        ],
      ),
    );
  }
}

class _AltarPropWidget extends StatelessWidget {
  const _AltarPropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 38,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF2E2C3D),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF7C4DFF), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFF7C4DFF).withValues(alpha: 0.4), blurRadius: 10),
              ],
            ),
          ),
          Pulse(
            duration: const Duration(milliseconds: 1600),
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFB388FF),
                boxShadow: [
                  BoxShadow(color: Color(0xFF7C4DFF), blurRadius: 8, spreadRadius: 2),
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 9, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _RugPropWidget extends StatelessWidget {
  const _RugPropWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF6B1724),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4),
        ],
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 12,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.6), width: 0.8),
          ),
        ),
      ),
    );
  }
}

class _ChairPropWidget extends StatelessWidget {
  const _ChairPropWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF4E342E),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF8D6E63), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 3),
        ],
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Color(0xFF795548),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
