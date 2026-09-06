import 'tile_types.dart';

/// Generates a royal citadel and castle stronghold with stone battlements,
/// an outer moat and drawbridge, a Grand Throne Room, Royal Banquet Hall,
/// Knights'' Armory, High Wizard''s Spire, and Treasury Vault.
class CastleGenerator {
  DungeonMap generate({required int seed, int width = 36, int height = 36}) {
    // Base layer: stone courtyard flagstones
    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.floor));

    final centerX = width ~/ 2;
    final centerY = height ~/ 2;

    // 1. Surrounding Deep Water Moat (2 tiles wide around perimeter at offset 2..3)
    for (int y = 2; y < height - 2; y++) {
      for (int x = 2; x < width - 2; x++) {
        final isMoat = (y == 2 || y == 3 || y == height - 3 || y == height - 4 ||
                        x == 2 || x == 3 || x == width - 3 || x == width - 4);
        if (isMoat) {
          tiles[y][x] = TileType.water;
        }
      }
    }

    // Central Drawbridge crossing the south moat into the courtyard
    for (int y = height - 4; y <= height - 2; y++) {
      tiles[y][centerX - 1] = TileType.floor;
      tiles[y][centerX] = TileType.floor;
      tiles[y][centerX + 1] = TileType.floor;
    }

    // 2. Outer Castle Curtain Wall (at offset 4)
    for (int y = 4; y < height - 4; y++) {
      for (int x = 4; x < width - 4; x++) {
        if (y == 4 || y == height - 5 || x == 4 || x == width - 5) {
          tiles[y][x] = TileType.wall;
        }
      }
    }

    // Grand Gatehouse Archway on the south curtain wall
    tiles[height - 5][centerX - 1] = TileType.door;
    tiles[height - 5][centerX] = TileType.door;
    tiles[height - 5][centerX + 1] = TileType.door;

    // 3. Castle Chambers and Halls (Rooms)
    final castleHalls = <Room>[
      // Center: Royal Throne Room & Dais
      Room(
        0,
        centerX - 4,
        centerY - 5,
        9,
        11,
        type: RoomType.bossChamber,
        name: 'High Throne Room of the Crown',
        description: 'Soaring granite arches line a crimson velvet carpet leading up to the gilded Lion Throne of the realm.',
      ),
      // North-West: Royal Banquet & Feast Hall
      Room(
        1,
        6,
        6,
        8,
        8,
        type: RoomType.ancientLibrary,
        name: 'Royal Banquet & Feast Hall',
        description: 'Long carved oak feast tables, wrought-iron candelabras, and tapestries depicting legendary dragonslayers.',
      ),
      // North-East: Arcane Spire & Wizard''s Sanctum
      Room(
        2,
        width - 14,
        6,
        8,
        8,
        type: RoomType.alchemistLab,
        name: "Archmage''s Celestial Spire",
        description: 'Glowing runic circles inscribed on obsidian tiles, astrolabes, and floating crystal orbs humming with power.',
      ),
      // South-West: Knights'' Guard Barracks & Armory
      Room(
        3,
        6,
        centerY + 3,
        8,
        7,
        type: RoomType.armory,
        name: "Kingsguard Armory & Barracks",
        description: 'Racks of tourney lances, silvered halberds, emblazoned shields, and weapon grindstones.',
      ),
      // South-East: Royal Treasury & Vault
      Room(
        4,
        width - 14,
        centerY + 3,
        8,
        7,
        type: RoomType.shrineSanctum,
        name: 'Royal Treasury Vault',
        description: 'Reinforced iron-bound vaults containing chest upon chest of minted crowns, jeweled chalices, and royal relics.',
      ),
      // South Courtyard: Outer Bailey & Training Grounds
      Room(
        5,
        centerX - 4,
        height - 9,
        9,
        4,
        type: RoomType.entryVestibule,
        name: 'Castle Outer Bailey',
        description: 'The open cobblestone courtyard between the drawbridge gatehouse and the high keep entrance.',
      ),
    ];

    // Carve walls for interior chambers 0 to 4
    for (final r in castleHalls) {
      if (r.id == 5) continue; // Outer Bailey is an open courtyard

      for (int dy = 0; dy < r.h; dy++) {
        for (int dx = 0; dx < r.w; dx++) {
          final x = r.x + dx;
          final y = r.y + dy;
          if (x >= 0 && x < width && y >= 0 && y < height) {
            final isBorder = dx == 0 || dx == r.w - 1 || dy == 0 || dy == r.h - 1;
            tiles[y][x] = isBorder ? TileType.wall : TileType.floor;
          }
        }
      }

      // Add entrance doors
      if (r.id == 0) {
        // Throne room entrance faces south towards bailey
        tiles[r.y + r.h - 1][r.centerX] = TileType.door;
      } else {
        final doorX = (r.x < centerX) ? (r.x + r.w - 1) : r.x;
        final doorY = r.centerY;
        if (doorX >= 0 && doorX < width && doorY >= 0 && doorY < height) {
          tiles[doorY][doorX] = TileType.door;
        }
      }
    }

    // Outer edge walls
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
          tiles[y][x] = TileType.wall;
        }
      }
    }

    return DungeonMap(
      tiles: tiles,
      rooms: castleHalls,
      entryPoint: Point(centerX, height - 7),
      seed: seed,
      width: width,
      height: height,
    );
  }
}
