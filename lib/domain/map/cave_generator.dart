import 'dart:math';
import 'tile_types.dart';

/// Generates an organic subterranean cavern and cave network with irregular rock
/// chambers, subterranean water pools, glowing crystal grottos, and mining tunnels.
class CaveGenerator {
  DungeonMap generate({required int seed, int width = 34, int height = 34}) {
    final rng = Random(seed);
    // Base layer: solid cavern rock walls
    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.wall));

    // 1. Defined Natural Cavern Chambers (Rooms)
    final rooms = <Room>[
      Room(0, 4, 4, 8, 8, type: RoomType.entryVestibule, name: 'Cavern Mouth Entry', description: 'A wide cavern vestibule where pale daylight from the surface gives way to subterranean dampness and echoing dripline.'),
      Room(1, 19, 4, 9, 8, type: RoomType.shrineSanctum, name: 'Glimmering Crystal Geode', description: 'Towering clusters of prismatic azurite and amethyst crystals protrude from the cavern walls, emitting soft ambient luminescence.'),
      Room(2, 4, 18, 9, 9, type: RoomType.floodedCrypt, name: 'Subterranean Sunken Lake', description: 'A serene underground lagoon of dark, glassy water reflecting the faint glow of phosphorescent algae on the high ceiling.'),
      Room(3, 20, 18, 8, 8, type: RoomType.armory, name: 'Dwarven Mine Excavation', description: 'Abandoned wooden mine shaft pilings, ore tracks, and iron wheelbarrows left behind by prospecting dwarven miners.'),
      Room(4, 12, 11, 10, 8, type: RoomType.ancientLibrary, name: 'Echoing Chasm Crossing', description: 'A vast underground chamber bisected by a natural stone bridge spanning a fathomless shadowy fissure.'),
      Room(5, 12, 24, 9, 7, type: RoomType.bossChamber, name: 'Ancient Cavern Sanctum', description: 'A primordial stone cavern altar surrounded by colossal stalactites and glowing subterranean heat fissures.'),
    ];

    // Carve irregular cavern floors in each chamber
    for (final r in rooms) {
      final cx = r.centerX;
      final cy = r.centerY;
      final rx = r.w / 2.0;
      final ry = r.h / 2.0;

      for (int y = r.y; y < r.y + r.h; y++) {
        for (int x = r.x; x < r.x + r.w; x++) {
          if (x <= 1 || y <= 1 || x >= width - 2 || y >= height - 2) continue;
          // Elliptical distance with natural perimeter noise
          final dx = (x - cx) / rx;
          final dy = (y - cy) / ry;
          final distSq = dx * dx + dy * dy;
          final noise = (rng.nextDouble() - 0.5) * 0.3;
          if (distSq + noise <= 1.0) {
            tiles[y][x] = (r.id == 2 && distSq < 0.45) ? TileType.water : TileType.floor;
          }
        }
      }
    }

    // 2. Connect chambers with winding organic tunnels
    for (int i = 1; i < rooms.length; i++) {
      final a = rooms[i - 1];
      final b = rooms[i];
      _carveOrganicTunnel(tiles, a.centerX, a.centerY, b.centerX, b.centerY, rng, width, height);
    }
    // Connect first and middle room for alternative loops
    _carveOrganicTunnel(tiles, rooms[0].centerX, rooms[0].centerY, rooms[4].centerX, rooms[4].centerY, rng, width, height);

    // 3. Ensure perimeter boundary stays solid cavern wall
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
          tiles[y][x] = TileType.wall;
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

  void _carveOrganicTunnel(List<List<TileType>> tiles, int x1, int y1, int x2, int y2, Random rng, int width, int height) {
    int curX = x1;
    int curY = y1;
    while (curX != x2 || curY != y2) {
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final tx = curX + dx;
          final ty = curY + dy;
          if (tx > 1 && ty > 1 && tx < width - 2 && ty < height - 2) {
            if (tiles[ty][tx] != TileType.water) {
              tiles[ty][tx] = TileType.floor;
            }
          }
        }
      }
      if (rng.nextBool()) {
        if (curX != x2) curX += (x2 > curX) ? 1 : -1;
      } else {
        if (curY != y2) curY += (y2 > curY) ? 1 : -1;
      }
    }
  }
}
