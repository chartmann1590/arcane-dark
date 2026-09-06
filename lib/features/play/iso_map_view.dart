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
  static const double wallRise = 32;

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
      props.where((p) => p.asset.contains('torch') || p.asset.contains('campfire') || p.asset.contains('brazier') || p.asset.contains('cauldron') || p.asset.contains('crystals')).map((p) => p.pos).toList();

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
          _IsoAtmosphericParticlesWidget(width: totalWidth, height: totalHeight, seed: dungeon.seed),
        ],
      ),
    );
  }

  Widget _buildTile(int x, int y, double originX, double originY, List<m.Point> torches) {
    final tile = dungeon.tileAt(x, y);
    final isWall = tile == m.TileType.wall || tile == m.TileType.mountain;
    final isDoor = tile == m.TileType.door;
    final isDoorOpen = openedDoors.contains('$x,$y');
    final isVisited = visited.contains('$x,$y');
    final isPlayer = playerPos.x == x && playerPos.y == y;
    final isTavern = environment == 'tavern';
    final canFog = !isTavern;

    final tileAsset = switch (tile) {
      m.TileType.wall => isTavern ? 'assets/tiles/wall_tavern.png' : 'assets/tiles/wall.png',
      m.TileType.floor => isTavern ? 'assets/tiles/floor_tavern.png' : 'assets/tiles/floor.png',
      m.TileType.door => isDoorOpen ? (isTavern ? 'assets/tiles/floor_tavern.png' : 'assets/tiles/floor.png') : 'assets/tiles/door.png',
      m.TileType.water => 'assets/tiles/water.png',
      m.TileType.forest => 'assets/tiles/forest.png',
      m.TileType.mountain => 'assets/tiles/mountain.png',
      m.TileType.plains => 'assets/tiles/plains.png',
    };

    final raised = isWall || (isDoor && !isDoorOpen);
    final riseH = raised ? wallRise : 0.0;
    final origin = _project(x, y, originX, originY);
    final lightIntensity = _lightIntensityAt(x, y, torches);
    final isTargetWaypoint = targetWaypoint != null && targetWaypoint!.x == x && targetWaypoint!.y == y;
    final isPathStep = activePath != null && activePath!.any((p) => p.x == x && p.y == y);

    // Wall adjacency for 3D ambient occlusion drop shadows
    final hasWallNW = x > 0 && dungeon.tileAt(x - 1, y) == m.TileType.wall;
    final hasWallNE = y > 0 && dungeon.tileAt(x, y - 1) == m.TileType.wall;
    final hasWallN = x > 0 && y > 0 && dungeon.tileAt(x - 1, y - 1) == m.TileType.wall;

    // Room theme query
    m.Room? room;
    for (final r in dungeon.rooms) {
      if (r.contains(m.Point(x, y))) {
        room = r;
        break;
      }
    }
    final isRoomCenter = room != null && room.centerX == x && room.centerY == y;

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
              top: 0,
              width: tileW,
              height: tileH + riseH,
              child: CustomPaint(
                size: Size(tileW, tileH + riseH),
                painter: _Iso3DWallPainter(
                  isDoor: isDoor && !isDoorOpen,
                  isTavern: isTavern,
                  torchGlow: lightIntensity,
                  isVisited: isVisited,
                  canFog: canFog,
                  riseH: riseH,
                ),
              ),
            )
          else ...[
            // Floor tile base & relief
            Positioned(
              left: 0,
              top: 0,
              width: tileW,
              height: tileH,
              child: ClipPath(
                clipper: _DiamondClipper(),
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(tileAsset, fit: BoxFit.fill),
                  // Multi-layered 3D Flagstone relief & room theme symbols
                  if (tile == m.TileType.floor || (isDoor && isDoorOpen))
                    CustomPaint(
                      size: const Size(tileW, tileH),
                      painter: _IsoFloorReliefPainter(
                        roomType: room?.type,
                        isRoomCenter: isRoomCenter,
                        torchGlow: lightIntensity,
                        tileSeed: (x * 31 + y * 17) & 0xFFFF,
                      ),
                    )
                  else if (tile == m.TileType.water)
                    const CustomPaint(
                      size: Size(tileW, tileH),
                      painter: _IsoWaterPainter(),
                    ),
                  // Ambient occlusion drop shadow cast from adjacent walls
                  if (hasWallNW || hasWallNE || hasWallN)
                    CustomPaint(
                      size: const Size(tileW, tileH),
                      painter: _IsoFloorShadowPainter(
                        hasWallNW: hasWallNW,
                        hasWallNE: hasWallNE,
                        hasWallN: hasWallN,
                      ),
                    ),
                  // Fog of War overlay
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
                  // Path waypoint dot
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
                  // Target waypoint bracket
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
          ],
        ]),
      ),
    );
  }

  bool _isFogged(m.Point pos) => environment != 'tavern' && !visited.contains('${pos.x},${pos.y}');

  Widget _buildProp(MapProp prop, double originX, double originY) {
    if (_isFogged(prop.pos)) return const SizedBox.shrink();
    final origin = _project(prop.pos.x, prop.pos.y, originX, originY);
    final isChest = prop.asset.contains('chest');
    final isGildedChest = prop.asset.contains('chest_gilded');
    final isTorch = prop.asset.contains('torch');
    final isCampfire = prop.asset.contains('campfire');
    final isBrazier = prop.asset.contains('brazier');
    final isBookshelf = prop.asset.contains('bookshelf');
    final isWeaponRack = prop.asset.contains('weapon_rack');
    final isAltar = prop.asset.contains('altar');
    final isRug = prop.asset.contains('rug');
    final isChair = prop.asset.contains('chair');
    final isCauldron = prop.asset.contains('cauldron');
    final isSarcophagus = prop.asset.contains('sarcophagus');
    final isLectern = prop.asset.contains('lectern');
    final isStatue = prop.asset.contains('statue');
    final isCrystals = prop.asset.contains('crystals');
    final isCrates = prop.asset.contains('crates');

    Offset propDown = Offset.zero;

    Widget childWidget;
    if (isGildedChest) {
      childWidget = const _ChestGildedWidget();
    } else if (isCauldron) {
      childWidget = const _CauldronPropWidget();
    } else if (isSarcophagus) {
      childWidget = const _SarcophagusPropWidget();
    } else if (isLectern) {
      childWidget = const _LecternPropWidget();
    } else if (isBrazier) {
      childWidget = const _BrazierPropWidget();
    } else if (isCampfire) {
      childWidget = const _CampfirePropWidget();
    } else if (isBookshelf) {
      childWidget = const _BookshelfPropWidget();
    } else if (isWeaponRack) {
      childWidget = const _WeaponRackPropWidget();
    } else if (isAltar) {
      childWidget = const _AltarPropWidget();
    } else if (isStatue) {
      childWidget = const _StatuePropWidget();
    } else if (isCrystals) {
      childWidget = const _CrystalClusterWidget();
    } else if (isCrates) {
      childWidget = const _CratesBarrelsWidget();
    } else if (isRug) {
      childWidget = const _RugPropWidget();
    } else if (isChair) {
      childWidget = const _ChairPropWidget();
    } else {
      childWidget = Image.asset(prop.asset, width: 48, height: 48, fit: BoxFit.contain);
    }

    return Positioned(
      left: origin.dx + tileW / 2 - 24,
      top: origin.dy - (isRug ? 10 : (isStatue ? 32 : 22)),
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
            if (!isRug)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 26,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
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

class _Iso3DWallPainter extends CustomPainter {
  final bool isDoor;
  final bool isTavern;
  final double torchGlow;
  final bool isVisited;
  final bool canFog;
  final double riseH;

  const _Iso3DWallPainter({
    required this.isDoor,
    this.isTavern = false,
    this.torchGlow = 0.0,
    this.isVisited = true,
    this.canFog = true,
    this.riseH = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const tileH = IsoMapView.tileH; // 32
    final rise = riseH;

    // Palette selection
    Color leftBase = isDoor
        ? const Color(0xFF2C1D13)
        : (isTavern ? const Color(0xFF2E2014) : const Color(0xFF1B1726));
    Color rightBase = isDoor
        ? const Color(0xFF4A3222)
        : (isTavern ? const Color(0xFF422E1D) : const Color(0xFF2E273F));
    Color topBase = isDoor
        ? const Color(0xFF382618)
        : (isTavern ? const Color(0xFF3B2A1B) : const Color(0xFF252033));

    if (torchGlow > 0) {
      leftBase = Color.lerp(leftBase, const Color(0xFF5E2E10), torchGlow * 0.45)!;
      rightBase = Color.lerp(rightBase, const Color(0xFF8C4616), torchGlow * 0.65)!;
      topBase = Color.lerp(topBase, const Color(0xFF703814), torchGlow * 0.55)!;
    }

    if (canFog && !isVisited) {
      final fogFactor = (0.95 - torchGlow * 0.35).clamp(0.0, 1.0);
      leftBase = Color.lerp(leftBase, const Color(0xFF090712), fogFactor)!;
      rightBase = Color.lerp(rightBase, const Color(0xFF0A0815), fogFactor)!;
      topBase = Color.lerp(topBase, const Color(0xFF0A0815), fogFactor)!;
    }

    // 1. FRONT-LEFT VERTICAL FACE (South-West facing, shadow side)
    final leftPath = Path()
      ..moveTo(0, tileH / 2)
      ..lineTo(w / 2, tileH)
      ..lineTo(w / 2, tileH + rise)
      ..lineTo(0, tileH / 2 + rise)
      ..close();

    final leftPaint = Paint()..color = leftBase;
    canvas.drawPath(leftPath, leftPaint);

    // Front-Left Ashlar Masonry Courses
    final mortarPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final brickHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const numRows = 3;
    final rowH = rise / numRows;
    for (var r = 1; r <= numRows; r++) {
      final yOff = r * rowH;
      canvas.drawLine(Offset(0, tileH / 2 + yOff), Offset(w / 2, tileH + yOff), mortarPaint);
      if (r < numRows) {
        canvas.drawLine(Offset(0, tileH / 2 + yOff + 0.8), Offset(w / 2, tileH + yOff + 0.8), brickHighlightPaint);
      }
      final t1 = (r % 2 == 1) ? 0.35 : 0.65;
      final jx1 = (w / 2) * t1;
      final jy1 = tileH / 2 + (tileH / 2) * t1 + yOff - rowH;
      canvas.drawLine(Offset(jx1, jy1), Offset(jx1, jy1 + rowH), mortarPaint);

      final t2 = (r % 2 == 1) ? 0.75 : 0.25;
      final jx2 = (w / 2) * t2;
      final jy2 = tileH / 2 + (tileH / 2) * t2 + yOff - rowH;
      canvas.drawLine(Offset(jx2, jy2), Offset(jx2, jy2 + rowH), mortarPaint);
    }

    // 2. FRONT-RIGHT VERTICAL FACE (South-East facing, lit side)
    final rightPath = Path()
      ..moveTo(w / 2, tileH)
      ..lineTo(w, tileH / 2)
      ..lineTo(w, tileH / 2 + rise)
      ..lineTo(w / 2, tileH + rise)
      ..close();

    final rightPaint = Paint()..color = rightBase;
    canvas.drawPath(rightPath, rightPaint);

    // Front-Right Ashlar Masonry Courses
    for (var r = 1; r <= numRows; r++) {
      final yOff = r * rowH;
      canvas.drawLine(Offset(w / 2, tileH + yOff), Offset(w, tileH / 2 + yOff), mortarPaint);
      if (r < numRows) {
        canvas.drawLine(Offset(w / 2, tileH + yOff + 0.8), Offset(w, tileH / 2 + yOff + 0.8), brickHighlightPaint);
      }
      final t1 = (r % 2 == 1) ? 0.35 : 0.65;
      final jx1 = (w / 2) + (w / 2) * t1;
      final jy1 = tileH - (tileH / 2) * t1 + yOff - rowH;
      canvas.drawLine(Offset(jx1, jy1), Offset(jx1, jy1 + rowH), mortarPaint);

      final t2 = (r % 2 == 1) ? 0.75 : 0.25;
      final jx2 = (w / 2) + (w / 2) * t2;
      final jy2 = tileH - (tileH / 2) * t2 + yOff - rowH;
      canvas.drawLine(Offset(jx2, jy2), Offset(jx2, jy2 + rowH), mortarPaint);
    }

    // Door hardware overlay on front-right face if door
    if (isDoor) {
      final ironPaint = Paint()..color = const Color(0xFF1E212B);
      final brassPaint = Paint()..color = const Color(0xFFFFB300);
      canvas.drawRect(Rect.fromLTWH(w / 2 + 4, tileH + 6, 18, 3), ironPaint);
      canvas.drawRect(Rect.fromLTWH(w / 2 + 4, tileH + rise - 10, 18, 3), ironPaint);
      canvas.drawCircle(Offset(w / 2 + 8, tileH + 7.5), 1.2, brassPaint);
      canvas.drawCircle(Offset(w / 2 + 18, tileH + 7.5), 1.2, brassPaint);
      canvas.drawCircle(Offset(w / 2 + 8, tileH + rise - 8.5), 1.2, brassPaint);
      canvas.drawCircle(Offset(w / 2 + 18, tileH + rise - 8.5), 1.2, brassPaint);
      canvas.drawCircle(Offset(w / 2 + 14, tileH + rise / 2), 3.5, ironPaint);
      canvas.drawCircle(Offset(w / 2 + 14, tileH + rise / 2), 2.0, Paint()..color = rightBase);
    }

    // Central Vertical Outer Corner Highlight
    final cornerHighlightPaint = Paint()
      ..color = Color.lerp(Colors.white.withValues(alpha: 0.25), const Color(0xFFFFD54F), torchGlow * 0.45)!
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(w / 2, tileH), Offset(w / 2, tileH + rise), cornerHighlightPaint);

    // Ground Contact Base Shadow Gradient
    final groundShadowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
      ).createShader(Rect.fromLTWH(0, tileH + rise - 6, w, 6));
    final baseShadowPath = Path()
      ..moveTo(0, tileH / 2 + rise - 4)
      ..lineTo(w / 2, tileH + rise - 4)
      ..lineTo(w, tileH / 2 + rise - 4)
      ..lineTo(w, tileH / 2 + rise)
      ..lineTo(w / 2, tileH + rise)
      ..lineTo(0, tileH / 2 + rise)
      ..close();
    canvas.drawPath(baseShadowPath, groundShadowPaint);

    // 3. TOP HORIZONTAL CAPSTONE (Isometric Diamond)
    final topPath = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, tileH / 2)
      ..lineTo(w / 2, tileH)
      ..lineTo(0, tileH / 2)
      ..close();

    final topPaint = Paint()..color = topBase;
    canvas.drawPath(topPath, topPaint);

    final litBevel = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.5;
    final shadowBevel = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(0, tileH / 2), Offset(w / 2, 0), litBevel);
    canvas.drawLine(Offset(w / 2, 0), Offset(w, tileH / 2), litBevel);
    canvas.drawLine(Offset(w, tileH / 2), Offset(w / 2, tileH), shadowBevel);
    canvas.drawLine(Offset(w / 2, tileH), Offset(0, tileH / 2), shadowBevel);

    final insetTop = Path()
      ..moveTo(w / 2, 3)
      ..lineTo(w - 6, tileH / 2)
      ..lineTo(w / 2, tileH - 3)
      ..lineTo(6, tileH / 2)
      ..close();
    final insetPaint = Paint()
      ..color = Color.lerp(topBase, Colors.black, 0.15)!
      ..style = PaintingStyle.fill;
    canvas.drawPath(insetTop, insetPaint);

    canvas.drawLine(Offset(w / 2, 3), Offset(w / 2, tileH - 3), mortarPaint);
    final rivetPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
    canvas.drawCircle(Offset(w / 2, 5), 1.2, rivetPaint);
    canvas.drawCircle(Offset(w / 2, tileH - 5), 1.2, rivetPaint);
    canvas.drawCircle(Offset(9, tileH / 2), 1.2, rivetPaint);
    canvas.drawCircle(Offset(w - 9, tileH / 2), 1.2, rivetPaint);
  }

  @override
  bool shouldRepaint(covariant _Iso3DWallPainter old) =>
      old.isDoor != isDoor ||
      old.isTavern != isTavern ||
      old.torchGlow != torchGlow ||
      old.isVisited != isVisited ||
      old.canFog != canFog ||
      old.riseH != riseH;
}

class _IsoFloorShadowPainter extends CustomPainter {
  final bool hasWallNW;
  final bool hasWallNE;
  final bool hasWallN;

  const _IsoFloorShadowPainter({
    required this.hasWallNW,
    required this.hasWallNE,
    required this.hasWallN,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final diamond = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.clipPath(diamond);

    if (hasWallNW) {
      final nwPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.center,
          colors: [
            Colors.black.withValues(alpha: 0.65),
            Colors.black.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w / 2, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w / 2, h), nwPaint);
    }

    if (hasWallNE) {
      final nePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.center,
          colors: [
            Colors.black.withValues(alpha: 0.60),
            Colors.black.withValues(alpha: 0.20),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(w / 4, 0, 3 * w / 4, h / 2));
      canvas.drawRect(Rect.fromLTWH(w / 4, 0, 3 * w / 4, h / 2), nePaint);
    }

    if (hasWallN || (hasWallNW && hasWallNE)) {
      final nPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.topCenter,
          radius: 0.5,
          colors: [
            Colors.black.withValues(alpha: 0.75),
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(w / 4, 0, w / 2, h / 2));
      canvas.drawCircle(Offset(w / 2, 0), 16, nPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IsoFloorShadowPainter old) =>
      old.hasWallNW != hasWallNW || old.hasWallNE != hasWallNE || old.hasWallN != hasWallN;
}

class _IsoFloorReliefPainter extends CustomPainter {
  final m.RoomType? roomType;
  final bool isRoomCenter;
  final double torchGlow;
  final int tileSeed;

  const _IsoFloorReliefPainter({
    this.roomType,
    this.isRoomCenter = false,
    this.torchGlow = 0.0,
    required this.tileSeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final diamond = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.clipPath(diamond);

    final mortarPaint = Paint()
      ..color = const Color(0xFF090710).withValues(alpha: 0.70)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final edgeLitPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(18, 9), Offset(46, 23), mortarPaint);
    canvas.drawLine(Offset(18, 8.3), Offset(46, 22.3), edgeLitPaint);
    canvas.drawLine(Offset(44, 10), Offset(20, 22), mortarPaint);
    canvas.drawLine(Offset(44, 9.3), Offset(20, 21.3), edgeLitPaint);

    final rng = Random(tileSeed);
    if (rng.nextBool()) {
      final stoneTint = Paint()..color = Colors.white.withValues(alpha: 0.04);
      final northStone = Path()
        ..moveTo(w / 2, 2)
        ..lineTo(44, 10)
        ..lineTo(32, 16)
        ..lineTo(20, 10)
        ..close();
      canvas.drawPath(northStone, stoneTint);
    }

    if (roomType != null) {
      switch (roomType!) {
        case m.RoomType.shrineSanctum:
          if (isRoomCenter) {
            final goldPaint = Paint()
              ..color = const Color(0xFFFFD54F).withValues(alpha: 0.75)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2;
            final glowPaint = Paint()
              ..color = const Color(0xFFFFB300).withValues(alpha: 0.25)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(Offset(w / 2, h / 2), 10, glowPaint);
            canvas.drawCircle(Offset(w / 2, h / 2), 9, goldPaint);
            canvas.drawCircle(Offset(w / 2, h / 2), 4, goldPaint);
            for (var i = 0; i < 8; i++) {
              final angle = i * pi / 4;
              canvas.drawLine(
                Offset(w / 2 + cos(angle) * 4, h / 2 + sin(angle) * 2),
                Offset(w / 2 + cos(angle) * 11, h / 2 + sin(angle) * 5.5),
                goldPaint,
              );
            }
          }
          break;

        case m.RoomType.alchemistLab:
          if (isRoomCenter) {
            final greenPaint = Paint()
              ..color = const Color(0xFF00E676).withValues(alpha: 0.75)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2;
            final greenGlow = Paint()
              ..color = const Color(0xFF00E676).withValues(alpha: 0.20)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(Offset(w / 2, h / 2), 11, greenGlow);
            canvas.drawCircle(Offset(w / 2, h / 2), 10, greenPaint);
            final tri = Path()
              ..moveTo(w / 2, h / 2 - 6)
              ..lineTo(w / 2 + 7, h / 2 + 4)
              ..lineTo(w / 2 - 7, h / 2 + 4)
              ..close();
            canvas.drawPath(tri, greenPaint);
          }
          break;

        case m.RoomType.ancientLibrary:
          if (isRoomCenter) {
            final runePaint = Paint()
              ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.75)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0;
            canvas.drawCircle(Offset(w / 2, h / 2), 10, runePaint);
            canvas.drawCircle(Offset(w / 2, h / 2), 6, runePaint);
            canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: 8, height: 4), runePaint);
          }
          break;

        case m.RoomType.treasureVault:
          final goldSeamPaint = Paint()
            ..color = const Color(0xFFFFD54F).withValues(alpha: 0.50)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          final innerVault = Path()
            ..moveTo(w / 2, 4)
            ..lineTo(w - 8, h / 2)
            ..lineTo(w / 2, h - 4)
            ..lineTo(8, h / 2)
            ..close();
          canvas.drawPath(innerVault, goldSeamPaint);
          break;

        case m.RoomType.bossChamber:
          final magmaPaint = Paint()
            ..color = const Color(0xFFFF3D00).withValues(alpha: 0.70)
            ..strokeWidth = 1.3
            ..style = PaintingStyle.stroke;
          final fissure = Path()
            ..moveTo(w / 2 - 12, h / 2 - 4)
            ..lineTo(w / 2 - 3, h / 2)
            ..lineTo(w / 2 + 2, h / 2 - 2)
            ..lineTo(w / 2 + 10, h / 2 + 3);
          canvas.drawPath(fissure, magmaPaint);
          break;

        case m.RoomType.floodedCrypt:
          final puddlePaint = Paint()
            ..color = const Color(0xFF006064).withValues(alpha: 0.40)
            ..style = PaintingStyle.fill;
          final causticPaint = Paint()
            ..color = const Color(0xFF80DEEA).withValues(alpha: 0.35)
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke;
          canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, h / 2), width: 22, height: 11), puddlePaint);
          canvas.drawArc(Rect.fromCenter(center: Offset(w / 2, h / 2), width: 14, height: 7), 0.5, 2.0, false, causticPaint);
          break;

        default:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IsoFloorReliefPainter old) =>
      old.roomType != roomType ||
      old.isRoomCenter != isRoomCenter ||
      old.torchGlow != torchGlow ||
      old.tileSeed != tileSeed;
}

class _IsoWaterPainter extends CustomPainter {
  const _IsoWaterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final diamond = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.clipPath(diamond);

    final waterShader = RadialGradient(
      center: Alignment.center,
      radius: 0.6,
      colors: const [
        Color(0xFF031622),
        Color(0xFF003847),
        Color(0xFF004D40),
      ],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = waterShader);

    final stepPaint = Paint()
      ..color = const Color(0xFF14242A).withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;
    final step = Path()
      ..moveTo(w / 2, 6)
      ..lineTo(w - 12, h / 2)
      ..lineTo(w / 2, h - 6)
      ..lineTo(12, h / 2)
      ..close();
    canvas.drawPath(step, stepPaint);

    final wavePaint = Paint()
      ..color = const Color(0xFF80DEEA).withValues(alpha: 0.40)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromCenter(center: Offset(w / 2 - 6, h / 2 - 2), width: 14, height: 6), 0.3, 2.2, false, wavePaint);
    canvas.drawArc(Rect.fromCenter(center: Offset(w / 2 + 5, h / 2 + 3), width: 16, height: 7), 3.4, 2.0, false, wavePaint);

    final foamPaint = Paint()
      ..color = const Color(0xFFB2EBF2).withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(diamond, foamPaint);
  }

  @override
  bool shouldRepaint(covariant _IsoWaterPainter old) => false;
}

class _StatuePropWidget extends StatelessWidget {
  const _StatuePropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: 32,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            child: Container(
              width: 30,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2838),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF4B445D), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 15,
            child: Container(
              width: 22,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF383347),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF5A5270), width: 1),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF635A7A),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF8B80A6), width: 1.2),
                  ),
                  child: const Center(
                    child: Icon(Icons.shield_rounded, size: 9, color: Color(0xFFB8AFD1)),
                  ),
                ),
                Container(
                  width: 20,
                  height: 15,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C4460),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF6E648A), width: 1),
                  ),
                  child: const Center(
                    child: Icon(Icons.navigation_rounded, size: 10, color: Color(0xFF9E94BA)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFB0BEC5),
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFECEFF1), blurRadius: 2),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            child: Container(
              width: 14,
              height: 2.5,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrystalClusterWidget extends StatelessWidget {
  const _CrystalClusterWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Pulse(
            duration: const Duration(milliseconds: 1600),
            child: Container(
              width: 38,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            child: Container(
              width: 30,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            child: Container(
              width: 28,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF262033),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF473C5C), width: 1.5),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 8,
            child: Transform.rotate(
              angle: -0.28,
              child: Container(
                width: 9,
                height: 22,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE040FB), Color(0xFF00E5FF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 8,
            child: Transform.rotate(
              angle: 0.32,
              child: Container(
                width: 8,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white, width: 0.8),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              width: 13,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFF00E5FF), Color(0xFF18FFFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF00E5FF), blurRadius: 8),
                ],
              ),
              child: Center(
                child: Container(
                  width: 2,
                  height: 26,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CratesBarrelsWidget extends StatelessWidget {
  const _CratesBarrelsWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ),
          Positioned(
            left: 2,
            bottom: 6,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF5D4037),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF8D6E63), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2)),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: 0.78,
                    child: Container(width: 26, height: 2, color: const Color(0xFF3E2723)),
                  ),
                  Transform.rotate(
                    angle: -0.78,
                    child: Container(width: 26, height: 2, color: const Color(0xFF3E2723)),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 6,
            child: Container(
              width: 20,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF4E342E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2E1C14), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(height: 2, color: const Color(0xFF90A4AE)),
                  Container(height: 2, color: const Color(0xFF90A4AE)),
                  Container(height: 2, color: const Color(0xFF90A4AE)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IsoAtmosphericParticlesWidget extends StatelessWidget {
  final double width;
  final double height;
  final int seed;
  const _IsoAtmosphericParticlesWidget({required this.width, required this.height, required this.seed});

  @override
  Widget build(BuildContext context) {
    final rng = Random(seed ^ 0x50415254);
    const count = 18;
    return SizedBox(
      width: width,
      height: height,
      child: IgnorePointer(
        child: Stack(
          children: [
            for (var i = 0; i < count; i++)
              Positioned(
                left: (rng.nextDouble() * width).clamp(20, width - 20),
                top: (rng.nextDouble() * height).clamp(20, height - 20),
                child: Pulse(
                  duration: Duration(milliseconds: 1500 + rng.nextInt(1500)),
                  child: Container(
                    width: 3.0 + rng.nextInt(3),
                    height: 3.0 + rng.nextInt(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i % 3 == 0
                          ? const Color(0xFFFFD54F).withValues(alpha: 0.65)
                          : i % 3 == 1
                              ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                              : const Color(0xFFE040FB).withValues(alpha: 0.55),
                      boxShadow: [
                        BoxShadow(
                          color: i % 3 == 0
                              ? const Color(0xFFFFB300).withValues(alpha: 0.5)
                              : const Color(0xFF00E5FF).withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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

class _CauldronPropWidget extends StatelessWidget {
  const _CauldronPropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Pulse(
            duration: const Duration(milliseconds: 1500),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withValues(alpha: 0.55),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 34,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E232A),
              border: Border.all(color: const Color(0xFF455A64), width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 3)),
              ],
            ),
          ),
          Container(
            width: 22,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF69F0AE), Color(0xFF00B0FF), Color(0xFF1B5E20)],
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 11,
            child: Transform.rotate(
              angle: 0.5,
              child: Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF8D6E63),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 12,
            left: 12,
            child: Icon(Icons.bubble_chart_rounded, size: 10, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SarcophagusPropWidget extends StatelessWidget {
  const _SarcophagusPropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF263238),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF546E7A), width: 1.8),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 6, offset: Offset(2, 3)),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF37474F),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF78909C), width: 1),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFD54F), width: 1),
                    ),
                    child: const Center(
                      child: Icon(Icons.lens, size: 4, color: Color(0xFFFFD54F)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 14,
                    height: 2,
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 9,
            child: Icon(Icons.masks_rounded, size: 14, color: Color(0xFFCFD8DC)),
          ),
        ],
      ),
    );
  }
}

class _LecternPropWidget extends StatelessWidget {
  const _LecternPropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF3E2723),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF6D4C41), width: 1.5),
              ),
            ),
          ),
          Positioned(
            top: 6,
            child: Container(
              width: 32,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF4E342E),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF8D6E63), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: 11,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    width: 11,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Pulse(
              duration: const Duration(milliseconds: 1400),
              child: const Icon(Icons.auto_stories_rounded, size: 14, color: Color(0xFF64B5F6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrazierPropWidget extends StatelessWidget {
  const _BrazierPropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Pulse(
            duration: const Duration(milliseconds: 1300),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6D00).withValues(alpha: 0.65),
                    blurRadius: 18,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            child: Container(
              width: 22,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF3E2723),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
              ),
            ),
          ),
          const Positioned(
            top: 2,
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 22,
              color: Color(0xFFFFAB00),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChestGildedWidget extends StatelessWidget {
  const _ChestGildedWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Pulse(
            duration: const Duration(milliseconds: 1700),
            child: Container(
              width: 34,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 34,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF4A148C),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFFFD54F), width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(2, 2)),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2.5, color: const Color(0xFFFFD54F)),
                ),
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2.5, color: const Color(0xFFFFD54F)),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF1744),
                    boxShadow: [
                      BoxShadow(color: Color(0xFFFF5252), blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
