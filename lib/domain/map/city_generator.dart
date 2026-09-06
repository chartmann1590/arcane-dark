import 'tile_types.dart';

/// Generates a sprawling medieval fantasy metropolis with grand paved boulevards,
/// a central market bazaar plaza, a canal waterway with stone footbridges,
/// a Grand Cathedral, Watch Barracks, Harbor Merchant Guild, and Guildhall.
class CityGenerator {
  DungeonMap generate({required int seed, int width = 36, int height = 36}) {
    // Base layer: dressed limestone street paving
    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.floor));

    final centerX = width ~/ 2;
    final centerY = height ~/ 2;

    // 1. Canal Waterway (runs vertically down the East quarter, e.g., x = 27..29)
    const canalX = 27;
    for (int y = 1; y < height - 1; y++) {
      for (int dx = 0; dx <= 2; dx++) {
        tiles[y][canalX + dx] = TileType.water;
      }
    }

    // Stone footbridges crossing the canal at y = 10, y = 18 (center avenue), y = 26
    final bridgeYs = [10, 18, 26];
    for (final by in bridgeYs) {
      for (int dx = 0; dx <= 2; dx++) {
        tiles[by][canalX + dx] = TileType.floor;
      }
    }

    // 2. Grand Central Avenue & Cross Thoroughfares (width 4)
    for (int y = 2; y < height - 2; y++) {
      for (int dx = -1; dx <= 2; dx++) {
        tiles[y][centerX + dx] = TileType.floor;
      }
    }
    for (int x = 2; x < canalX; x++) {
      for (int dy = -1; dy <= 2; dy++) {
        tiles[centerY + dy][x] = TileType.floor;
      }
    }

    // 3. Central Market Plaza (large open square in the center)
    for (int dy = -6; dy <= 6; dy++) {
      for (int dx = -6; dx <= 6; dx++) {
        tiles[centerY + dy][centerX + dx] = TileType.floor;
      }
    }

    // 4. Prominent City Districts & Edifices (Rooms)
    final districts = <Room>[
      // Center: Grand Market Bazaar
      Room(
        0,
        centerX - 5,
        centerY - 5,
        11,
        11,
        type: RoomType.entryVestibule,
        name: 'Grand Market Bazaar',
        description: 'A roaring metropolis marketplace filled with vibrant silk canopies, exotic spice merchants, gem traders, and street entertainers.',
      ),
      // North-West: High Citadel & Governor\'s Hall
      Room(
        1,
        3,
        3,
        9,
        8,
        type: RoomType.bossChamber,
        name: "High Citadel & Governor's Palace",
        description: 'Polished white marble columns, majestic stained-glass clerestories, and the gilded seat of the City Magistrate.',
      ),
      // North-East: Grand Cathedral of the Sun
      Room(
        2,
        centerX + 4,
        3,
        8,
        8,
        type: RoomType.shrineSanctum,
        name: 'Grand Cathedral of the Sun',
        description: 'Sunlight streams through vaulted gold-leaf arches onto sacred altars, where high clerics chant solemn hymns of warding.',
      ),
      // South-West: City Watch Barracks & Armory
      Room(
        3,
        3,
        centerY + 3,
        9,
        8,
        type: RoomType.armory,
        name: 'City Watch Barracks & Armory',
        description: 'Heavy oak weapon racks, rows of polished steel breastplates, target dummies, and holding cells for lawbreakers.',
      ),
      // South-East: Harbor Guild & Trade Vaults
      Room(
        4,
        centerX + 4,
        centerY + 3,
        8,
        8,
        type: RoomType.ancientLibrary,
        name: 'Harbor Guild & Trade Vaults',
        description: 'Stacks of ledger books, navigation astrolabes, sealed crates of overseas spices, and chests of trade ingots.',
      ),
      // East Canal Bank: Harbor Pier & Water Gate
      Room(
        5,
        canalX + 3,
        14,
        5,
        8,
        type: RoomType.floodedCrypt,
        name: 'Canal Water Gate & Docks',
        description: 'Mooring posts, coiled mooring ropes, and freight skiffs transporting goods through the city canals.',
      ),
    ];

    // Carve walled structures around buildings 1 to 4
    for (final d in districts) {
      if (d.id == 0) continue; // Bazaar is an open plaza
      if (d.id == 5) continue; // Docks are open waterfront

      for (int dy = 0; dy < d.h; dy++) {
        for (int dx = 0; dx < d.w; dx++) {
          final x = d.x + dx;
          final y = d.y + dy;
          if (x >= 0 && x < width && y >= 0 && y < height) {
            final isBorder = dx == 0 || dx == d.w - 1 || dy == 0 || dy == d.h - 1;
            tiles[y][x] = isBorder ? TileType.wall : TileType.floor;
          }
        }
      }

      // Add entrance doorways facing the central streets
      final doorX = (d.x < centerX) ? (d.x + d.w - 1) : d.x;
      final doorY = d.centerY;
      if (doorX >= 0 && doorX < width && doorY >= 0 && doorY < height) {
        tiles[doorY][doorX] = TileType.door;
      }
    }

    // 5. Outer City Defensive Stone Walls & Perimeter Gates
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
          tiles[y][x] = TileType.wall;
        }
      }
    }

    // Main city gates (openings in the perimeter wall)
    tiles[0][centerX] = TileType.door;
    tiles[0][centerX + 1] = TileType.door;
    tiles[height - 1][centerX] = TileType.door;
    tiles[height - 1][centerX + 1] = TileType.door;

    return DungeonMap(
      tiles: tiles,
      rooms: districts,
      entryPoint: Point(centerX, centerY),
      seed: seed,
      width: width,
      height: height,
    );
  }
}
