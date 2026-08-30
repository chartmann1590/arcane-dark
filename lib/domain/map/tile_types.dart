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
}
