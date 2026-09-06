import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final void Function(PetCompanion pet)? onPetTap;
  final void Function(PartyMemberVisual member)? onPartyMemberTap;
  final List<SidequestMarker>? sidequestMarkers;

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
    this.onPetTap,
    this.onPartyMemberTap,
    this.sidequestMarkers,
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
    final totalHeight = (dungeon.width + dungeon.height) * tileH / 2 + wallRise + tileH * 2 + 32;
    final torches = _torchPositions;

    final renderItems = <_IsoRenderItem>[];

    // 1. All map tiles (ground layer 10, wall/tree layer 70)
    for (var y = 0; y < dungeon.height; y++) {
      for (var x = 0; x < dungeon.width; x++) {
        final tile = dungeon.tileAt(x, y);
        final isWall = tile == m.TileType.wall || tile == m.TileType.mountain;
        final layer = isWall ? 70.0 : 10.0;
        final depth = (x + y) * 100.0 + layer;
        renderItems.add(_IsoRenderItem(
          depth: depth,
          widget: _buildTile(x, y, originX, originY, torches),
        ));
      }
    }

    // 2. Props (rugs 15, low ground props 25, tall furniture/statues 65)
    for (final prop in props) {
      if (!_isFogged(prop.pos)) {
        final isRug = prop.asset.contains('rug');
        final isTall = prop.asset.contains('statue') || prop.asset.contains('bookshelf') || prop.asset.contains('altar');
        final layer = isRug ? 15.0 : (isTall ? 65.0 : 25.0);
        final depth = (prop.pos.x + prop.pos.y) * 100.0 + layer;
        renderItems.add(_IsoRenderItem(
          depth: depth,
          widget: _buildProp(prop, originX, originY),
        ));
      }
    }

    // 3. Animals (layer 35)
    for (final animal in animals) {
      if (!_isFogged(animal.pos)) {
        final depth = (animal.pos.x + animal.pos.y) * 100.0 + 35.0;
        renderItems.add(_IsoRenderItem(
          depth: depth,
          widget: _buildAnimal(animal, originX, originY),
        ));
      }
    }

    // 4. Pet Companion (layer 40)
    if (activePet != null && activePet!.id != 'none') {
      final depth = (playerPos.x + playerPos.y) * 100.0 + 40.0;
      renderItems.add(_IsoRenderItem(
        depth: depth,
        widget: _buildPetCompanion(activePet!, originX, originY),
      ));
    }

    // 5. NPCs (layer 45)
    for (final npc in npcs) {
      if (!_isFogged(npc.pos)) {
        final depth = (npc.pos.x + npc.pos.y) * 100.0 + 45.0;
        renderItems.add(_IsoRenderItem(
          depth: depth,
          widget: _buildNpc(npc, originX, originY),
        ));
      }
    }

    // 6. Party Members (Player + AI Companions, layer 50)
    if (partyMembers.isNotEmpty) {
      for (var i = 0; i < partyMembers.length; i++) {
        final mPos = partyMembers[i].pos ?? playerPos;
        final depth = (mPos.x + mPos.y) * 100.0 + 50.0 + (i * 0.1);
        renderItems.add(_IsoRenderItem(
          depth: depth,
          widget: _buildPartyMember(partyMembers[i], i, originX, originY),
        ));
      }
    } else {
      final depth = (playerPos.x + playerPos.y) * 100.0 + 50.0;
      renderItems.add(_IsoRenderItem(
        depth: depth,
        widget: _buildPartyMember(const PartyMemberVisual(name: 'You', portraitAsset: null), 0, originX, originY),
      ));
    }

    // 7. Sidequest Beacons (layer 85)
    for (final beacon in sidequestMarkers ?? const <SidequestMarker>[]) {
      if (!_isFogged(beacon.pos)) {
        final depth = (beacon.pos.x + beacon.pos.y) * 100.0 + 85.0;
        renderItems.add(_IsoRenderItem(
          depth: depth,
          widget: _buildSidequestBeacon(beacon, originX, originY),
        ));
      }
    }

    // Sort strictly by depth (Painter's Algorithm: back-to-front rendering)
    renderItems.sort((a, b) => a.depth.compareTo(b.depth));

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in renderItems) item.widget,
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
    final isForest = environment == 'forest';
    final isVillage = environment == 'village';
    final isCave = environment == 'cave';
    final isTavern = environment == 'tavern';
    final isCity = environment == 'city';
    final isCastle = environment == 'castle';
    final canFog = !isTavern && !isVillage && !isCity && !isCastle;

    final tileAsset = switch (tile) {
      m.TileType.wall => isTavern ? 'assets/tiles/wall_tavern.png' : 'assets/tiles/wall.png',
      m.TileType.floor => isTavern ? 'assets/tiles/floor_tavern.png' : 'assets/tiles/floor.png',
      m.TileType.door => isDoorOpen ? (isTavern ? 'assets/tiles/floor_tavern.png' : 'assets/tiles/floor.png') : 'assets/tiles/door.png',
      m.TileType.water => 'assets/tiles/water.png',
      m.TileType.forest => 'assets/tiles/forest.png',
      m.TileType.mountain => 'assets/tiles/mountain.png',
      m.TileType.plains => 'assets/tiles/plains.png',
    };

    // Cutaway South Walls: A wall that borders a walkable floor to its North/West
    // is between the room and the camera. Render with low cutaway curb (12px)
    // so the camera looks directly into the room without obstructing characters!
    final hasFloorNorth = (x > 0 && dungeon.tileAt(x - 1, y).walkable) ||
        (y > 0 && dungeon.tileAt(x, y - 1).walkable) ||
        (x > 0 && y > 0 && dungeon.tileAt(x - 1, y - 1).walkable);

    final raised = isWall || (isDoor && !isDoorOpen);
    final riseH = raised
        ? (isForest && isWall
            ? 38.0
            : (hasFloorNorth ? 12.0 : wallRise))
        : 0.0;
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

    Offset downPos = const Offset(-999, -999);

    return Positioned(
      left: origin.dx,
      top: origin.dy - riseH,
      width: tileW,
      height: tileH + riseH,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          final localY = e.localPosition.dy - (raised ? wallRise : 0);
          final inDiamond = (e.localPosition.dx - 32).abs() / 32.0 + (localY - 16).abs() / 16.0 <= 1.0;
          if (inDiamond) {
            downPos = e.position;
          } else {
            downPos = const Offset(-999, -999);
          }
        },
        onPointerUp: (e) {
          if (downPos.dx > -900 && (e.position - downPos).distanceSquared < 400) {
            final localY = e.localPosition.dy - (raised ? wallRise : 0);
            final inDiamond = (e.localPosition.dx - 32).abs() / 32.0 + (localY - 16).abs() / 16.0 <= 1.0;
            if (inDiamond) {
              onTileTap?.call(m.Point(x, y));
            }
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
                painter: (isForest && isWall)
                    ? _Iso3DTreePainter(
                        torchGlow: lightIntensity,
                        isVisited: isVisited,
                        canFog: canFog,
                        treeSeed: (x * 47 + y * 89) & 0xFFFF,
                      )
                    : _Iso3DWallPainter(
                        isDoor: isDoor && !isDoorOpen,
                        isTavern: isTavern,
                        isVillage: isVillage,
                        isCave: isCave,
                        isCity: isCity,
                        isCastle: isCastle,
                        torchGlow: lightIntensity,
                        isVisited: isVisited,
                        canFog: canFog,
                        riseH: riseH,
                        isCutaway: hasFloorNorth,
                      ),
              ),
            )
          else ...[
            // 3D Floor Slab Skirt (gives floor tiles physical isometric thickness & depth)
            Positioned(
              left: 0,
              top: 0,
              width: tileW,
              height: tileH + 4,
              child: CustomPaint(
                size: const Size(tileW, tileH + 4),
                painter: _IsoFloor3DSlabPainter(
                  torchGlow: lightIntensity,
                  isVisited: isVisited,
                  canFog: canFog,
                ),
              ),
            ),
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
                  if (tile == m.TileType.floor || (isDoor && isDoorOpen) || tile == m.TileType.plains)
                    CustomPaint(
                      size: const Size(tileW, tileH),
                      painter: _IsoFloorReliefPainter(
                        roomType: room?.type,
                        isRoomCenter: isRoomCenter,
                        torchGlow: lightIntensity,
                        tileSeed: (x * 31 + y * 17) & 0xFFFF,
                        environment: environment,
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
    final isLootedChest = prop.asset.contains('chest_open');
    final isChest = prop.asset.contains('chest') && !isLootedChest;
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
    final isCrystals = prop.asset.contains('crystals') || prop.asset.contains('geode');
    final isCrates = prop.asset.contains('crates');
    final isFountain = prop.asset.contains('fountain') || prop.asset.contains('well');
    final isForge = prop.asset.contains('forge') || prop.asset.contains('anvil');
    final isStall = prop.asset.contains('stall') || prop.asset.contains('market');
    final isShrine = prop.asset.contains('shrine');
    final isCart = prop.asset.contains('cart') || prop.asset.contains('wagon');
    final isThrone = prop.asset.contains('throne');
    final isTable = prop.asset.contains('table');
    final isBarCounter = prop.asset.contains('bar_counter') || prop.asset.contains('counter');

    Offset propDown = Offset.zero;

    Widget childWidget;
    if (isLootedChest) {
      childWidget = const _LootedChestWidget();
    } else if (isGildedChest) {
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
    } else if (isFountain) {
      childWidget = const _FountainPropWidget();
    } else if (isForge) {
      childWidget = const _ForgePropWidget();
    } else if (isStall) {
      childWidget = const _MarketStallPropWidget();
    } else if (isShrine) {
      childWidget = const _ShrinePropWidget();
    } else if (isCart) {
      childWidget = const _CartPropWidget();
    } else if (isThrone) {
      childWidget = const _ThronePropWidget();
    } else if (isTable) {
      childWidget = const _TablePropWidget();
    } else if (isBarCounter) {
      childWidget = const _BarCounterPropWidget();
    } else {
      childWidget = Image.asset(
        prop.asset,
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => _GenericPropWidget(prop: prop),
      );
    }

    return Positioned(
      left: origin.dx + tileW / 2 - 24,
      top: origin.dy + 18.0 - (isRug ? 16 : (isStatue ? 48 : 34)),
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
      'rat' => '🐀',
      'beetle' => '🪲',
      'frog' => '🐸',
      _ => animal.emoji.isNotEmpty ? animal.emoji : '🐾',
    };

    return Positioned(
      left: origin.dx + tileW / 2 - 13,
      top: origin.dy + 18.0 - 26,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onAnimalTap == null ? null : (_) => onAnimalTap!(animal),
        child: Pulse(
          duration: const Duration(milliseconds: 2000),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: -2,
                child: Container(
                  width: 20,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Container(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetCompanion(PetCompanion pet, double originX, double originY) {
    final origin = _project(playerPos.x, playerPos.y, originX, originY);
    final isFlying = pet.isFlying;
    final petX = origin.dx + tileW / 2 + (isFlying ? 11 : 9);
    final petY = origin.dy + 18.0 - (isFlying ? 36 : 24);

    return Positioned(
      left: petX,
      top: petY,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPetTap?.call(pet),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Isometric Ground Drop Shadow beneath pet
            Positioned(
              top: isFlying ? 28 : 20,
              child: Container(
                width: isFlying ? 14 : 18,
                height: isFlying ? 6 : 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black.withValues(alpha: isFlying ? 0.35 : 0.65),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: isFlying ? 5 : 2,
                    ),
                  ],
                ),
              ),
            ),

            // 2. Animated Pet Token Body with Elemental Aura
            Pulse(
              duration: Duration(milliseconds: isFlying ? 1400 : 2000),
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      pet.color.withValues(alpha: 0.35),
                      const Color(0xFF161022),
                      const Color(0xFF090612),
                    ],
                    stops: const [0.2, 0.7, 1.0],
                  ),
                  border: Border.all(
                    color: pet.color,
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: pet.color.withValues(alpha: 0.8),
                      blurRadius: 9,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    pet.emoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),

            // 3. Mini Pet Perk Indicator Badge
            Positioned(
              right: -2,
              bottom: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pet.color,
                  border: Border.all(color: Colors.white, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: pet.color.withValues(alpha: 0.8),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNpc(MapNpc npc, double originX, double originY) {
    if (_isFogged(npc.pos)) return const SizedBox.shrink();
    final origin = _project(npc.pos.x, npc.pos.y, originX, originY);
    final token = Padding(padding: const EdgeInsets.all(4), child: _NpcToken(npc: npc));
    return Positioned(
      left: origin.dx + tileW / 2 - 20,
      top: origin.dy + 18.0 - (npc.isHostile ? 38 : 34),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onNpcTap == null ? null : (_) => onNpcTap!(npc),
        child: npc.isHostile ? Pulse(duration: const Duration(milliseconds: 1400), child: token) : token,
      ),
    );
  }

  static const _clusterOffsets = [
    Offset(0, 0),
    Offset(-6, 2),
    Offset(6, 2),
    Offset(-4, -3),
    Offset(4, -3),
  ];

  Widget _buildPartyMember(PartyMemberVisual member, int index, double originX, double originY) {
    final pos = member.pos ?? playerPos;
    final origin = _project(pos.x, pos.y, originX, originY);
    final sharingTile = pos.x == playerPos.x && pos.y == playerPos.y;
    Offset offset = sharingTile ? _clusterOffsets[index % _clusterOffsets.length] : Offset.zero;

    // Strict boundary adherence: ensure character is never pushed towards or over adjacent walls
    if (offset.dy < 0 && (pos.y > 0 && dungeon.tileAt(pos.x, pos.y - 1) == m.TileType.wall ||
        pos.x > 0 && dungeon.tileAt(pos.x - 1, pos.y) == m.TileType.wall)) {
      offset = Offset(offset.dx, 0);
    }
    if (offset.dx < 0 && pos.x > 0 && dungeon.tileAt(pos.x - 1, pos.y) == m.TileType.wall) {
      offset = Offset(0, offset.dy);
    }
    if (offset.dx > 0 && pos.x < dungeon.width - 1 && dungeon.tileAt(pos.x + 1, pos.y) == m.TileType.wall) {
      offset = Offset(0, offset.dy);
    }

    final isLead = index == 0;
    final tokenSize = isLead ? 30.0 : 26.0;
    // Grounding: tile diamond center floor line is origin.dy + 16.0.
    // Miniature token stands upright planted firmly on the floor slab:
    final tokenLeft = origin.dx + tileW / 2 - tokenSize / 2 + offset.dx;
    final tokenTop = origin.dy + 16.0 - tokenSize + offset.dy;

    final token = _PartyToken(
      portraitAsset: member.portraitAsset,
      isLead: isLead,
      speechBubble: member.speechBubble,
      name: member.name,
    );

    return Positioned(
      left: tokenLeft,
      top: tokenTop,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (member.onTap != null) {
            member.onTap!();
          } else if (onPartyMemberTap != null) {
            onPartyMemberTap!(member);
          }
        },
        child: token,
      ),
    );
  }

  Widget _buildSidequestBeacon(SidequestMarker beacon, double originX, double originY) {
    if (_isFogged(beacon.pos)) return const SizedBox.shrink();
    final origin = _project(beacon.pos.x, beacon.pos.y, originX, originY);
    return Positioned(
      left: origin.dx + tileW / 2 - 20,
      top: origin.dy - 18,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: beacon.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pulse(
              duration: const Duration(milliseconds: 1400),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                  border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 1),
                  ],
                ),
                child: Text(beacon.icon, style: const TextStyle(fontSize: 14)),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF140F22).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.6), width: 0.5),
              ),
              child: Text(
                beacon.title,
                style: GoogleFonts.cinzel(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFFFFD54F)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
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

class _IsoMiniatureBasePainter extends CustomPainter {
  final Color ringColor;
  final bool isLead;

  const _IsoMiniatureBasePainter({
    required this.ringColor,
    required this.isLead,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width;
    final h = size.height;

    // 1. Isometric 2:1 Contact Drop Shadow firmly on the floor slab
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.70)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 2.5), width: w * 0.98, height: h * 0.88),
      shadowPaint,
    );

    // 2. 3D Miniature Figurine Plinth Vertical Rim (beveled side extrusion)
    final rimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLead
            ? [const Color(0xFFC67C00), const Color(0xFF4A2E00)]
            : [const Color(0xFF00838F), const Color(0xFF003830)],
      ).createShader(Rect.fromLTWH(0, cy, w, 4.0));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 1.5), width: w * 0.88, height: h * 0.74),
      rimPaint,
    );

    // 3. 3D Beveled Top Plinth Face (isometric tabletop miniature base plate)
    final topPlinthPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isLead
            ? [const Color(0xFFFFE082), const Color(0xFFFFD54F), const Color(0xFFFFA000)]
            : [const Color(0xFFB2EBF2), const Color(0xFF80DEEA), const Color(0xFF26C6DA)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 0.5), width: w * 0.84, height: h * 0.68),
      topPlinthPaint,
    );

    // 4. Metallic Highlight Bevel Ring
    final bevelPaint = Paint()
      ..color = Colors.white.withValues(alpha: isLead ? 0.70 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 0.5), width: w * 0.84, height: h * 0.68),
      bevelPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _IsoMiniatureBasePainter old) =>
      old.ringColor != ringColor || old.isLead != isLead;
}

class _PartyToken extends StatelessWidget {
  final String? portraitAsset;
  final bool isLead;
  final String? speechBubble;
  final String? name;
  const _PartyToken({
    this.portraitAsset,
    this.isLead = true,
    this.speechBubble,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLead ? 30.0 : 26.0;
    final color = isLead ? ArcaneTheme.primary : ArcaneTheme.secondary;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 1. Isometric 2:1 Tabletop Plinth Base & Floor Contact Shadow
        Positioned(
          bottom: -4,
          child: CustomPaint(
            size: Size(size * 1.15, size * 0.58),
            painter: _IsoMiniatureBasePainter(
              ringColor: color,
              isLead: isLead,
            ),
          ),
        ),
        // 2. Lead Hero Soft Breathing Aura (glows gently without lifting token off base)
        if (isLead)
          Positioned.fill(
            child: Pulse(
              duration: const Duration(milliseconds: 1600),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.50),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        // 3. Upright Character Portrait Avatar Token
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isLead ? 2.2 : 1.6),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isLead ? 0.65 : 0.45),
                blurRadius: isLead ? 10 : 6,
                spreadRadius: isLead ? 1 : 0,
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
            image: portraitAsset != null ? DecorationImage(image: AssetImage(portraitAsset!), fit: BoxFit.cover) : null,
            color: portraitAsset == null ? color : null,
          ),
          child: portraitAsset == null ? Icon(Icons.person_rounded, size: isLead ? 17 : 14, color: Colors.white) : null,
        ),
        // Lead Hero Crown Badge
        if (isLead)
          Positioned(
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 3),
                ],
              ),
              child: const Text('👑', style: TextStyle(fontSize: 8)),
            ),
          ),
        // Speech / Banter bubble over character head
        if (speechBubble != null && speechBubble!.isNotEmpty)
          Positioned(
            bottom: size + 6,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 150),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF141220).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 6),
                  ],
                ),
                child: Text(
                  speechBubble!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class PartyMemberVisual {
  final String name;
  final String? portraitAsset;
  final m.Point? pos;
  final String? speechBubble;
  final VoidCallback? onTap;
  const PartyMemberVisual({
    required this.name,
    this.portraitAsset,
    this.pos,
    this.speechBubble,
    this.onTap,
  });
}

class SidequestMarker {
  final m.Point pos;
  final String title;
  final String icon;
  final VoidCallback? onTap;
  const SidequestMarker({
    required this.pos,
    required this.title,
    this.icon = '📜',
    this.onTap,
  });
}

/// Depth-sorted renderable item for Painter's Algorithm in isometric diorama.
class _IsoRenderItem {
  final double depth;
  final Widget widget;
  const _IsoRenderItem({required this.depth, required this.widget});
}

/// 3D Layered Isometric Canopy Tree for Forest and Wilderness environments.
class _Iso3DTreePainter extends CustomPainter {
  final double torchGlow;
  final bool isVisited;
  final bool canFog;
  final int treeSeed;

  const _Iso3DTreePainter({
    this.torchGlow = 0.0,
    this.isVisited = true,
    this.canFog = true,
    this.treeSeed = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const tileH = IsoMapView.tileH; // 32
    final centerX = w / 2;
    final groundY = tileH + 12.0;

    // 1. Isometric Ground Drop Shadow beneath tree base
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, groundY - 4), width: 38, height: 16),
      shadowPaint,
    );

    // 2. Sturdy Wooden Tree Trunk
    final trunkBase = groundY - 6;
    const trunkHeight = 22.0;
    final trunkTop = trunkBase - trunkHeight;

    final trunkPath = Path()
      ..moveTo(centerX - 5, trunkBase)
      ..lineTo(centerX - 3.5, trunkTop)
      ..lineTo(centerX + 3.5, trunkTop)
      ..lineTo(centerX + 5, trunkBase)
      ..close();

    final trunkGradient = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0xFF2E1C0C),
        Color(0xFF4E3620),
        Color(0xFF382312),
      ],
    );
    final trunkPaint = Paint()
      ..shader = trunkGradient.createShader(Rect.fromLTWH(centerX - 5, trunkTop, 10, trunkHeight));
    canvas.drawPath(trunkPath, trunkPaint);

    // 3. Layered 3D Isometric Foliage Canopies
    // Layer 1 (Bottom Tier - Broadest & Deep Forest Green)
    _drawCanopyTier(
      canvas,
      centerX: centerX,
      centerY: trunkTop + 4,
      width: 46,
      height: 24,
      baseColor: const Color(0xFF133926),
      highlightColor: const Color(0xFF1E5238),
      torchGlow: torchGlow,
      fogFactor: (canFog && !isVisited) ? 0.8 : 0.0,
    );

    // Layer 2 (Middle Tier - Lush Vibrant Emerald)
    _drawCanopyTier(
      canvas,
      centerX: centerX,
      centerY: trunkTop - 8,
      width: 38,
      height: 22,
      baseColor: const Color(0xFF1E593E),
      highlightColor: const Color(0xFF2D7A56),
      torchGlow: torchGlow,
      fogFactor: (canFog && !isVisited) ? 0.8 : 0.0,
    );

    // Layer 3 (Top Crown Tier - Sunlight Highlighted Leaf Crown)
    _drawCanopyTier(
      canvas,
      centerX: centerX,
      centerY: trunkTop - 20,
      width: 28,
      height: 18,
      baseColor: const Color(0xFF2D7A56),
      highlightColor: const Color(0xFF45A274),
      torchGlow: torchGlow,
      fogFactor: (canFog && !isVisited) ? 0.8 : 0.0,
    );

    // Subtle sunlit top pinnacle
    final pinnaclePaint = Paint()
      ..color = const Color(0xFF68C997).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, trunkTop - 26), 2.2, pinnaclePaint);
  }

  void _drawCanopyTier(
    Canvas canvas, {
    required double centerX,
    required double centerY,
    required double width,
    required double height,
    required Color baseColor,
    required Color highlightColor,
    required double torchGlow,
    required double fogFactor,
  }) {
    Color litBase = baseColor;
    Color litHigh = highlightColor;
    if (torchGlow > 0) {
      litBase = Color.lerp(litBase, const Color(0xFFD4A347), torchGlow * 0.35)!;
      litHigh = Color.lerp(litHigh, const Color(0xFFFFD54F), torchGlow * 0.45)!;
    }
    if (fogFactor > 0) {
      litBase = Color.lerp(litBase, const Color(0xFF090A12), fogFactor)!;
      litHigh = Color.lerp(litHigh, const Color(0xFF0B0E18), fogFactor)!;
    }

    final path = Path()
      ..moveTo(centerX, centerY - height / 2)
      ..lineTo(centerX + width / 2, centerY)
      ..lineTo(centerX, centerY + height / 2)
      ..lineTo(centerX - width / 2, centerY)
      ..close();

    final grad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [litHigh, litBase, Color.lerp(litBase, Colors.black, 0.35)!],
      stops: const [0.0, 0.55, 1.0],
    );
    final p = Paint()..shader = grad.createShader(Rect.fromCenter(center: Offset(centerX, centerY), width: width, height: height));
    canvas.drawPath(path, p);

    final bevelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, bevelPaint);
  }

  @override
  bool shouldRepaint(covariant _Iso3DTreePainter old) =>
      old.torchGlow != torchGlow ||
      old.isVisited != isVisited ||
      old.canFog != canFog ||
      old.treeSeed != treeSeed;
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
  final bool isVillage;
  final bool isCave;
  final bool isCity;
  final bool isCastle;
  final double torchGlow;
  final bool isVisited;
  final bool canFog;
  final double riseH;
  final bool isCutaway;

  const _Iso3DWallPainter({
    required this.isDoor,
    this.isTavern = false,
    this.isVillage = false,
    this.isCave = false,
    this.isCity = false,
    this.isCastle = false,
    this.torchGlow = 0.0,
    this.isVisited = true,
    this.canFog = true,
    this.riseH = 32.0,
    this.isCutaway = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const tileH = IsoMapView.tileH; // 32
    final rise = riseH;

    // Palette selection
    Color leftBase;
    Color rightBase;
    Color topBase;

    if (isDoor) {
      leftBase = const Color(0xFF2C1D13);
      rightBase = const Color(0xFF4A3222);
      topBase = const Color(0xFF382618);
    } else if (isCastle) {
      // Imperial dark granite fortress
      leftBase = const Color(0xFF1E222A);
      rightBase = const Color(0xFF343B48);
      topBase = const Color(0xFF282F3B);
    } else if (isCity) {
      // Dressed ashlar limestone
      leftBase = const Color(0xFF8A7968);
      rightBase = const Color(0xFFA69A89);
      topBase = const Color(0xFF988C7B);
    } else if (isVillage) {
      // Medieval timber & warm stucco
      leftBase = const Color(0xFFB8A692);
      rightBase = const Color(0xFFD4C5B3);
      topBase = const Color(0xFFC7B7A4);
    } else if (isCave) {
      // Rough subterranean cave rock
      leftBase = const Color(0xFF161820);
      rightBase = const Color(0xFF252936);
      topBase = const Color(0xFF1E212B);
    } else if (isTavern) {
      leftBase = const Color(0xFF2E2014);
      rightBase = const Color(0xFF422E1D);
      topBase = const Color(0xFF3B2A1B);
    } else {
      leftBase = const Color(0xFF1B1726);
      rightBase = const Color(0xFF2E273F);
      topBase = const Color(0xFF252033);
    }

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

    final mortarPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final brickHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final numRows = rise <= 14.0 ? 1 : 3;
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

    // Timber framing overlay for village walls
    if (isVillage && !isDoor && rise > 14.0) {
      final timberPaint = Paint()
        ..color = const Color(0xFF3E2723).withValues(alpha: 0.85)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(0, tileH / 2), Offset(w / 2, tileH + rise), timberPaint);
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

    // Timber framing overlay for village walls
    if (isVillage && !isDoor && rise > 14.0) {
      final timberPaint = Paint()
        ..color = const Color(0xFF3E2723).withValues(alpha: 0.85)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(w / 2, tileH + rise), Offset(w, tileH / 2), timberPaint);
    }

    // Royal heraldic pennant overlay for castle fortress walls
    if (isCastle && !isDoor && rise > 14.0) {
      final bannerPaint = Paint()..color = const Color(0xFF4A148C).withValues(alpha: 0.85);
      final goldTrim = Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.85)..strokeWidth = 1.0;
      final bx = w / 2 + 7;
      final by = tileH + 4;
      canvas.drawRect(Rect.fromLTWH(bx, by, 9, (rise - 8).clamp(8.0, 20.0)), bannerPaint);
      canvas.drawLine(Offset(bx, by), Offset(bx + 9, by), goldTrim);
      canvas.drawLine(Offset(bx + 4.5, by + 1), Offset(bx + 4.5, by + (rise - 9).clamp(7.0, 19.0)), goldTrim);
    }

    // Ornate bronze sconce overlay for metropolis city walls
    if (isCity && !isDoor && rise > 14.0) {
      final bronzePaint = Paint()..color = const Color(0xFFCD7F32).withValues(alpha: 0.9)..strokeWidth = 1.5;
      final glowPaint = Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.75);
      final sx = w / 2 + 10;
      final sy = tileH + rise * 0.45;
      canvas.drawLine(Offset(sx, sy), Offset(sx + 4, sy - 4), bronzePaint);
      canvas.drawCircle(Offset(sx + 4, sy - 5), 2.0, glowPaint);
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
      old.isVillage != isVillage ||
      old.isCave != isCave ||
      old.isCity != isCity ||
      old.isCastle != isCastle ||
      old.torchGlow != torchGlow ||
      old.isVisited != isVisited ||
      old.canFog != canFog ||
      old.riseH != riseH ||
      old.isCutaway != isCutaway;
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

class _IsoFloor3DSlabPainter extends CustomPainter {
  final double torchGlow;
  final bool isVisited;
  final bool canFog;

  const _IsoFloor3DSlabPainter({
    this.torchGlow = 0.0,
    this.isVisited = true,
    this.canFog = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const tileH = IsoMapView.tileH;
    const slabDepth = 3.5;

    // Dark shadow side (South-West facet)
    Color leftSlab = const Color(0xFF100C18);
    // Directional light side (South-East facet)
    Color rightSlab = const Color(0xFF1C1426);

    if (torchGlow > 0) {
      leftSlab = Color.lerp(leftSlab, const Color(0xFF381E10), torchGlow * 0.45)!;
      rightSlab = Color.lerp(rightSlab, const Color(0xFF542A16), torchGlow * 0.60)!;
    }

    if (canFog && !isVisited) {
      leftSlab = const Color(0xFF07050C);
      rightSlab = const Color(0xFF08060E);
    }

    // Left slab facet
    final leftPath = Path()
      ..moveTo(0, tileH / 2)
      ..lineTo(w / 2, tileH)
      ..lineTo(w / 2, tileH + slabDepth)
      ..lineTo(0, tileH / 2 + slabDepth)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = leftSlab);

    // Right slab facet
    final rightPath = Path()
      ..moveTo(w / 2, tileH)
      ..lineTo(w, tileH / 2)
      ..lineTo(w, tileH / 2 + slabDepth)
      ..lineTo(w / 2, tileH + slabDepth)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = rightSlab);

    // Seam lines & corner bevel
    final seamPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, tileH / 2 + slabDepth), Offset(w / 2, tileH + slabDepth), seamPaint);
    canvas.drawLine(Offset(w / 2, tileH + slabDepth), Offset(w, tileH / 2 + slabDepth), seamPaint);
    canvas.drawLine(Offset(w / 2, tileH), Offset(w / 2, tileH + slabDepth), seamPaint);
  }

  @override
  bool shouldRepaint(covariant _IsoFloor3DSlabPainter old) =>
      old.torchGlow != torchGlow || old.isVisited != isVisited;
}

class _IsoFloorReliefPainter extends CustomPainter {
  final m.RoomType? roomType;
  final bool isRoomCenter;
  final double torchGlow;
  final int tileSeed;
  final String environment;

  const _IsoFloorReliefPainter({
    this.roomType,
    this.isRoomCenter = false,
    this.torchGlow = 0.0,
    required this.tileSeed,
    this.environment = 'dungeon',
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

    // Environment-specific relief details
    if (environment == 'village') {
      final cobblePaint = Paint()
        ..color = const Color(0xFF6D6356).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final cobbleFill = Paint()
        ..color = const Color(0xFFDCD2C3).withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.35, h * 0.4), width: 14, height: 7), cobbleFill);
      canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.35, h * 0.4), width: 14, height: 7), cobblePaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.65, h * 0.42), width: 12, height: 6), cobbleFill);
      canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.65, h * 0.42), width: 12, height: 6), cobblePaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.65), width: 15, height: 8), cobbleFill);
      canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.65), width: 15, height: 8), cobblePaint);
    } else if (environment == 'forest') {
      final trailPaint = Paint()
        ..color = const Color(0xFF3E2718).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(w * 0.25, h * 0.35), Offset(w * 0.75, h * 0.65), trailPaint);
      final mossPaint = Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: 0.30)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(w * 0.3, h * 0.6), 2.5, mossPaint);
      canvas.drawCircle(Offset(w * 0.7, h * 0.35), 2.0, mossPaint);
    } else if (environment == 'cave') {
      final crackPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawLine(Offset(w * 0.3, h * 0.3), Offset(w * 0.5, h * 0.5), crackPaint);
      canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.7, h * 0.45), crackPaint);
    } else if (environment == 'city') {
      final paverPaint = Paint()
        ..color = const Color(0xFF5D5345).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final paverFill = Paint()
        ..color = const Color(0xFFC7BCA9).withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: 22, height: 11), paverFill);
      canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: 22, height: 11), paverPaint);
      final brassGrate = Paint()
        ..color = const Color(0xFFB8860B).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(Offset(w * 0.5, h * 0.5), 3, brassGrate);
    } else if (environment == 'castle') {
      final runnerPaint = Paint()
        ..color = const Color(0xFF8B0000).withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      final goldTrim = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final runnerPath = Path()
        ..moveTo(w * 0.25, h * 0.25)
        ..lineTo(w * 0.75, h * 0.75)
        ..lineTo(w * 0.85, h * 0.65)
        ..lineTo(w * 0.35, h * 0.15)
        ..close();
      canvas.drawPath(runnerPath, runnerPaint);
      canvas.drawLine(Offset(w * 0.25, h * 0.25), Offset(w * 0.75, h * 0.75), goldTrim);
    }

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
      old.tileSeed != tileSeed ||
      old.environment != environment;
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
            // Low-lying eerie crypt mist wisps
            for (var m = 0; m < 8; m++)
              Positioned(
                left: (rng.nextDouble() * width).clamp(20, width - 60),
                top: (rng.nextDouble() * height).clamp(20, height - 40),
                child: Pulse(
                  duration: Duration(milliseconds: 3200 + rng.nextInt(2200)),
                  child: Container(
                    width: 44.0 + rng.nextInt(28),
                    height: 14.0 + rng.nextInt(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF90CAF9).withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
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

class _LootedChestWidget extends StatelessWidget {
  const _LootedChestWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Open ironbound chest base
          Container(
            width: 32,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF3E2C1E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF1E140C), width: 1.5),
            ),
          ),
          // Opened tilted lid
          Positioned(
            top: 4,
            left: 2,
            child: Transform.rotate(
              angle: -0.38,
              child: Container(
                width: 30,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFF533B28),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFF2C1D12), width: 1.2),
                ),
              ),
            ),
          ),
          // Claimed gold coin remnants
          Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD54F))),
                const SizedBox(width: 2),
                Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFC107))),
                const SizedBox(width: 2),
                Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFE082))),
              ],
            ),
          ),
        ],
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

class _FountainPropWidget extends StatelessWidget {
  const _FountainPropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF37474F),
              border: Border.all(color: const Color(0xFF78909C), width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 3)),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1976D2).withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(color: const Color(0xFF42A5F5).withValues(alpha: 0.6), blurRadius: 6),
              ],
            ),
          ),
          const Icon(Icons.water_drop_rounded, size: 16, color: Color(0xFFE1F5FE)),
        ],
      ),
    );
  }
}

class _ForgePropWidget extends StatelessWidget {
  const _ForgePropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF212121),
              border: Border.all(color: const Color(0xFFFF6F00), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF6F00).withValues(alpha: 0.5), blurRadius: 8),
              ],
            ),
          ),
          const Icon(Icons.hardware_rounded, size: 18, color: Color(0xFFFFB300)),
        ],
      ),
    );
  }
}

class _MarketStallPropWidget extends StatelessWidget {
  const _MarketStallPropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF5D4037),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF8D6E63), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 3)),
              ],
            ),
          ),
          Positioned(
            top: 6,
            child: Container(
              width: 36,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFC62828),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.white70, width: 0.8),
              ),
            ),
          ),
          const Positioned(
            bottom: 10,
            child: Icon(Icons.storefront_rounded, size: 16, color: Color(0xFFFFE082)),
          ),
        ],
      ),
    );
  }
}

class _ShrinePropWidget extends StatelessWidget {
  const _ShrinePropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF263238),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), blurRadius: 10),
              ],
            ),
          ),
          const Icon(Icons.auto_awesome_rounded, size: 20, color: Color(0xFFFFD54F)),
        ],
      ),
    );
  }
}

class _CartPropWidget extends StatelessWidget {
  const _CartPropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 38,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF4E342E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF795548), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 3)),
              ],
            ),
          ),
          const Icon(Icons.agriculture_rounded, size: 20, color: Color(0xFFBCAAA4)),
        ],
      ),
    );
  }
}

class _TablePropWidget extends StatelessWidget {
  const _TablePropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: 36,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
          Container(
            width: 38,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF5D4037),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF8D6E63), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: const Center(
              child: Icon(Icons.table_restaurant_rounded, size: 14, color: Color(0xFFD7CCC8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarCounterPropWidget extends StatelessWidget {
  const _BarCounterPropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: 40,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
          Container(
            width: 42,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF3E2723),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF6D4C41), width: 1.8),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.sports_bar_rounded, size: 13, color: Color(0xFFFFB300)),
                Container(width: 8, height: 12, decoration: BoxDecoration(color: const Color(0xFF8D6E63), borderRadius: BorderRadius.circular(2))),
                const Icon(Icons.sports_bar_rounded, size: 13, color: Color(0xFFFFB300)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenericPropWidget extends StatelessWidget {
  final MapProp prop;
  const _GenericPropWidget({required this.prop});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2438),
              border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.7), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          ),
          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFD54F)),
        ],
      ),
    );
  }
}

class _ThronePropWidget extends StatelessWidget {
  const _ThronePropWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Golden backrest dais
          Positioned(
            top: 4,
            child: Container(
              width: 32,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFB8860B),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(color: const Color(0xFFFFD700), width: 1.8),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
                ],
              ),
            ),
          ),
          // Crimson velvet cushion
          Positioned(
            top: 18,
            child: Container(
              width: 24,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFFD700), width: 1.0),
              ),
            ),
          ),
          // Crown icon
          const Positioned(
            top: 8,
            child: Icon(Icons.shield_rounded, size: 16, color: Color(0xFFFFE082)),
          ),
        ],
      ),
    );
  }
}
