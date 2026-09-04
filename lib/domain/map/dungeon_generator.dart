import 'dart:math';
import 'tile_types.dart';

class DungeonGenerator {
  DungeonMap generate({required int seed, int width = 32, int height = 32}) {
    final rng = Random(seed);
    // Start filled with wall
    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.wall));

    final rooms = <Room>[];
    // BSP: generate a bigger, more varied room count via rejection sampling
    // (simple, deterministic, reliable) — randomized per-seed so different
    // buildings/dungeons feel like genuinely different-sized spaces, not a
    // fixed template stamped out every time.
    final targetRooms = 11 + rng.nextInt(6); // 11..16
    int attempts = 0;
    int roomId = 0;
    while (rooms.length < targetRooms && attempts < 500) {
      attempts++;
      final w = 5 + rng.nextInt(8); // 5..12
      final h = 5 + rng.nextInt(8);
      final x = 1 + rng.nextInt(width - w - 2);
      final y = 1 + rng.nextInt(height - h - 2);
      final candidate = Room(roomId, x, y, w, h);
      bool overlaps = false;
      for (final r in rooms) {
        if (_overlaps(candidate, r, 1)) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) {
        rooms.add(candidate);
        roomId++;
        // carve
        for (int dy = 0; dy < h; dy++) {
          for (int dx = 0; dx < w; dx++) {
            tiles[y + dy][x + dx] = TileType.floor;
          }
        }
      }
    }

    if (rooms.isEmpty) {
      // fallback single room center
      final r = Room(0, width ~/ 4, height ~/ 4, width ~/ 2, height ~/ 2);
      rooms.add(r);
      for (int dy = 0; dy < r.h; dy++) {
        for (int dx = 0; dx < r.w; dx++) tiles[r.y + dy][r.x + dx] = TileType.floor;
      }
    }

    // Connect rooms with L-shaped corridors in order of generation (ensures fully connected)
    for (int i = 1; i < rooms.length; i++) {
      final a = rooms[i - 1];
      final b = rooms[i];
      _carveCorridor(tiles, a.centerX, a.centerY, b.centerX, b.centerY);
    }

    // Place doors at corridor-room intersections
    for (final r in rooms) {
      // Check horizontal boundary (top & bottom edges)
      for (final y in [r.y, r.y + r.h - 1]) {
        for (var x = r.x + 1; x < r.x + r.w - 1; x++) {
          if (tiles[y][x] == TileType.floor) {
            final leftWall = x > 0 && tiles[y][x - 1] == TileType.wall;
            final rightWall = x < width - 1 && tiles[y][x + 1] == TileType.wall;
            if (leftWall && rightWall) {
              tiles[y][x] = TileType.door;
            }
          }
        }
      }
      // Check vertical boundary (left & right edges)
      for (final x in [r.x, r.x + r.w - 1]) {
        for (var y = r.y + 1; y < r.y + r.h - 1; y++) {
          if (tiles[y][x] == TileType.floor) {
            final topWall = y > 0 && tiles[y - 1][x] == TileType.wall;
            final bottomWall = y < height - 1 && tiles[y + 1][x] == TileType.wall;
            if (topWall && bottomWall) {
              tiles[y][x] = TileType.door;
            }
          }
        }
      }
    }

    // Ensure entry at first room center
    final entry = Point(rooms.first.centerX, rooms.first.centerY);

    // Verify connectivity with flood fill; if not connected, carve extra corridor directly from disconnected room to entry
    final reachable = _floodFill(tiles, entry);
    for (final r in rooms) {
      if (!reachable.contains('${r.centerX},${r.centerY}')) {
        _carveCorridor(tiles, entry.x, entry.y, r.centerX, r.centerY);
      }
    }

    return DungeonMap(tiles: tiles, rooms: rooms, entryPoint: entry, seed: seed, width: width, height: height);
  }

  bool _overlaps(Room a, Room b, int pad) {
    return !(a.x + a.w + pad <= b.x || b.x + b.w + pad <= a.x || a.y + a.h + pad <= b.y || b.y + b.h + pad <= a.y);
  }

  void _carveCorridor(List<List<TileType>> tiles, int x1, int y1, int x2, int y2) {
    // L-shaped: horizontal then vertical, with random choice of elbow
    final midX = x2;
    // horizontal segment
    final hx1 = min(x1, midX);
    final hx2 = max(x1, midX);
    for (int x = hx1; x <= hx2; x++) {
      tiles[y1][x] = TileType.floor;
      // widen slightly for nicer look
      if (y1 > 0) {
        // keep walls but ensure walkable center
      }
    }
    // vertical segment
    final vy1 = min(y1, y2);
    final vy2 = max(y1, y2);
    for (int y = vy1; y <= vy2; y++) {
      tiles[y][midX] = TileType.floor;
    }
  }

  Set<String> _floodFill(List<List<TileType>> tiles, Point start) {
    final visited = <String>{};
    final queue = [start];
    final h = tiles.length, w = tiles[0].length;
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      final key = '${p.x},${p.y}';
      if (visited.contains(key)) continue;
      if (p.x < 0 || p.y < 0 || p.x >= w || p.y >= h) continue;
      if (tiles[p.y][p.x] == TileType.wall || tiles[p.y][p.x] == TileType.water || tiles[p.y][p.x] == TileType.mountain) continue;
      visited.add(key);
      queue.add(Point(p.x + 1, p.y));
      queue.add(Point(p.x - 1, p.y));
      queue.add(Point(p.x, p.y + 1));
      queue.add(Point(p.x, p.y - 1));
    }
    return visited;
  }
}
