import 'dart:math';
import 'tile_types.dart';

/// Generates an expansive outdoor forest & wilderness map featuring natural
/// clearings, winding dirt trails, river streams, wooden bridges, and tree groves.
class ForestGenerator {
  DungeonMap generate({required int seed, int width = 34, int height = 34}) {
    final rng = Random(seed);
    // Base layer: lush plains/grass
    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.plains));

    // 1. Procedural River winding through the forest from top-right to bottom-left
    int riverX = width - 4 - rng.nextInt(6);
    final riverTiles = <Point>{};
    for (int y = 0; y < height; y++) {
      riverX += rng.nextInt(3) - 1;
      riverX = riverX.clamp(3, width - 4);
      for (int rx = -1; rx <= 1; rx++) {
        final x = riverX + rx;
        if (x >= 0 && x < width) {
          tiles[y][x] = TileType.water;
          riverTiles.add(Point(x, y));
        }
      }
    }

    // 2. Clearings / Landmarks (Rooms)
    final rooms = <Room>[
      Room(0, 4, 4, 7, 7, type: RoomType.entryVestibule, name: 'Ranger Trailhead Clearing', description: 'Sunlight filters through towering evergreens onto a peaceful mossy clearing where the forest path begins.'),
      Room(1, 15, 5, 8, 7, type: RoomType.shrineSanctum, name: 'Ancient Druid Grove', description: 'Ancient moss-covered menhirs circle an illuminated stone altar resonating with the heartbeat of the wilds.'),
      Room(2, 5, 16, 8, 7, type: RoomType.ancientLibrary, name: 'Hermit Sage Encampment', description: 'A cozy hollow flanked by aged willows, featuring a warm campfire ring and drying herbal medicine racks.'),
      Room(3, 20, 16, 7, 7, type: RoomType.armory, name: 'Woodcutter Timber Yard', description: 'Stacked pine timber and sturdy split logs surround an active timber workshop under the trees.'),
      Room(4, 8, 25, 8, 6, type: RoomType.treasureVault, name: 'Sunken Brook Clearing', description: 'A tranquil riverbank glade where crystal-clear water pools against smooth river stones and wild ferns.'),
      Room(5, 22, 24, 7, 7, type: RoomType.bossChamber, name: 'Wolf Crag Overlook', description: 'A rugged plateau crowned with granite boulders, overlooking the sweeping expanse of the ancient woodland.'),
    ];

    // Carve open grass/plains in all rooms
    for (final r in rooms) {
      for (int dy = 0; dy < r.h; dy++) {
        for (int dx = 0; dx < r.w; dx++) {
          final x = r.x + dx;
          final y = r.y + dy;
          if (x >= 0 && x < width && y >= 0 && y < height) {
            tiles[y][x] = TileType.plains;
          }
        }
      }
    }

    // 3. Connect rooms with winding dirt pathways (TileType.floor)
    for (int i = 1; i < rooms.length; i++) {
      final a = rooms[i - 1];
      final b = rooms[i];
      _carveWindingTrail(tiles, a.centerX, a.centerY, b.centerX, b.centerY, rng);
    }

    // Connect last room to first to create loop trails
    _carveWindingTrail(tiles, rooms.last.centerX, rooms.last.centerY, rooms.first.centerX, rooms.first.centerY, rng);

    // 4. Wooden Footbridges across the river where paths cross water
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (tiles[y][x] == TileType.water) {
          final hasPathW = tiles[y][x - 1] == TileType.floor;
          final hasPathE = tiles[y][x + 1] == TileType.floor;
          final hasPathN = tiles[y - 1][x] == TileType.floor;
          final hasPathS = tiles[y + 1][x] == TileType.floor;
          if ((hasPathW && hasPathE) || (hasPathN && hasPathS)) {
            tiles[y][x] = TileType.floor; // Wooden bridge planking
          }
        }
      }
    }

    // Ensure at least one guaranteed bridge across river near mid-height
    final midY = height ~/ 2;
    for (int x = 0; x < width; x++) {
      if (tiles[midY][x] == TileType.water) {
        tiles[midY][x] = TileType.floor;
      }
    }

    // 5. Populate outer dense forest borders & tree clusters with TileType.wall (renders as 3D canopy trees!)
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Outer perimeter trees
        if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
          tiles[y][x] = TileType.wall;
          continue;
        }
        // Don't place trees inside rooms or directly on pathways or water
        if (tiles[y][x] == TileType.water || tiles[y][x] == TileType.floor) continue;
        bool inRoom = false;
        for (final r in rooms) {
          if (r.contains(Point(x, y))) {
            inRoom = true;
            break;
          }
        }
        if (!inRoom) {
          // Cluster trees naturally
          final treeChance = (x < 3 || x > width - 4 || y < 3 || y > height - 4) ? 0.75 : 0.40;
          if (rng.nextDouble() < treeChance) {
            tiles[y][x] = TileType.wall;
          }
        }
      }
    }

    return DungeonMap(
      tiles: tiles,
      rooms: rooms,
      entryPoint: Point(rooms[0].centerX, rooms[0].centerY),
      seed: seed,
      width: width,
      height: height,
    );
  }

  void _carveWindingTrail(List<List<TileType>> tiles, int x1, int y1, int x2, int y2, Random rng) {
    int curX = x1;
    int curY = y1;
    while (curX != x2 || curY != y2) {
      if (tiles[curY][curX] != TileType.water) {
        tiles[curY][curX] = TileType.floor; // Winding trail
      }
      if (rng.nextBool()) {
        if (curX != x2) curX += (x2 > curX) ? 1 : -1;
      } else {
        if (curY != y2) curY += (y2 > curY) ? 1 : -1;
      }
    }
  }
}
