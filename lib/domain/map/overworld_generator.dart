import 'dart:math';
import 'tile_types.dart';

class OverworldGenerator {
  DungeonMap generate({required int seed, int width = 32, int height = 32}) {
    final rng = Random(seed);
    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.plains));
    // Simple noise-like: random blobs
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final n = _noise(x, y, seed);
        if (n > 0.6) tiles[y][x] = TileType.mountain;
        else if (n > 0.45) tiles[y][x] = TileType.forest;
        else if (n < 0.15) tiles[y][x] = TileType.water;
        else tiles[y][x] = TileType.plains;
      }
    }
    // Ensure a walkable center area for spawn
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        final cx = width ~/ 2 + dx, cy = height ~/ 2 + dy;
        if (cx >= 0 && cx < width && cy >= 0 && cy < height) tiles[cy][cx] = TileType.plains;
      }
    }
    return DungeonMap(
      tiles: tiles,
      rooms: [Room(0, width ~/ 2 - 2, height ~/ 2 - 2, 5, 5)],
      entryPoint: Point(width ~/ 2, height ~/ 2),
      seed: seed,
      width: width,
      height: height,
    );
  }

  double _noise(int x, int y, int seed) {
    // Cheap deterministic hash noise
    final n = (x * 374761393 + y * 668265263 + seed * 1274126177) & 0x7fffffff;
    return (n % 1000) / 1000.0;
  }
}
