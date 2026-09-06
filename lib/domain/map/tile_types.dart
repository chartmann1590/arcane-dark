enum TileType {
  wall,
  floor,
  door,
  water,
  forest,
  mountain,
  plains,
}

extension TileTypeExt on TileType {
  bool get walkable => this == TileType.floor || this == TileType.door || this == TileType.plains || this == TileType.forest;
  String get label => switch (this) {
        TileType.wall => 'wall',
        TileType.floor => 'floor',
        TileType.door => 'door',
        TileType.water => 'water',
        TileType.forest => 'forest',
        TileType.mountain => 'mountain',
        TileType.plains => 'plains',
      };
}

class Room {
  final int x, y, w, h;
  final int id;
  Room(this.id, this.x, this.y, this.w, this.h);
  int get centerX => x + w ~/ 2;
  int get centerY => y + h ~/ 2;
}

class DungeonMap {
  final List<List<TileType>> tiles;
  final List<Room> rooms;
  final Point entryPoint;
  final int seed;
  final int width;
  final int height;
  DungeonMap({required this.tiles, required this.rooms, required this.entryPoint, required this.seed, required this.width, required this.height});

  TileType tileAt(int x, int y) {
    if (x < 0 || y < 0 || y >= height || x >= width) return TileType.wall;
    return tiles[y][x];
  }

  String describeRoom(int roomId) {
    final r = rooms.firstWhere((e) => e.id == roomId, orElse: () => rooms.first);
    final sizeLabel = (r.w * r.h) > 80 ? 'vast' : (r.w * r.h) > 40 ? 'spacious' : 'cramped';
    return 'a $sizeLabel stone chamber (${r.w}x${r.h}), torchlight flickering on damp walls';
  }
}

class Point {
  final int x, y;
  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) => identical(this, other) || other is Point && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  int manhattanDistance(Point other) => (x - other.x).abs() + (y - other.y).abs();
}

/// Computes the shortest walkable path between two points on the dungeon map via BFS.
/// Respects [closedDoors] as passage blockers unless the door tile itself is the destination.
/// Respects [blockedTiles] as impassable obstacles (e.g. solid furniture, pillars).
/// Returns null if unreachable or if the target is non-walkable.
List<Point>? findPath(
  DungeonMap map,
  Point start,
  Point target, {
  Set<String> closedDoors = const {},
  Set<String> blockedTiles = const {},
}) {
  if (start == target) return [];
  if (target.x < 0 || target.y < 0 || target.x >= map.width || target.y >= map.height) return null;
  if (!map.tileAt(target.x, target.y).walkable) return null;
  if (blockedTiles.contains('${target.x},${target.y}')) return null;

  final queue = <Point>[start];
  final cameFrom = <Point, Point>{};
  final visited = <Point>{start};

  const deltas = [Point(0, -1), Point(0, 1), Point(-1, 0), Point(1, 0)];

  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    if (cur == target) {
      final path = <Point>[];
      var curr = cur;
      while (curr != start) {
        path.add(curr);
        curr = cameFrom[curr]!;
      }
      return path.reversed.toList();
    }

    // A closed door blocks passage onward, but can be the final destination to interact with it
    if (cur != start && closedDoors.contains('${cur.x},${cur.y}')) {
      continue;
    }

    for (final d in deltas) {
      final next = Point(cur.x + d.x, cur.y + d.y);
      if (next.x >= 0 &&
          next.y >= 0 &&
          next.x < map.width &&
          next.y < map.height &&
          !visited.contains(next) &&
          !blockedTiles.contains('${next.x},${next.y}') &&
          map.tileAt(next.x, next.y).walkable) {
        visited.add(next);
        cameFrom[next] = cur;
        queue.add(next);
      }
    }
  }
  return null;
}
