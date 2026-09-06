import 'tile_types.dart';

/// Generates a detailed medieval/fantasy village and town map with cobblestone
/// streets, central town square fountain, timber buildings, shops, forge, and tavern.
class VillageGenerator {
  DungeonMap generate({required int seed, int width = 34, int height = 34}) {
    // Base layer: grassy village ground
    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.plains));

    // 1. Broad Cobblestone Main Thoroughfares (cross formation through center)
    final centerX = width ~/ 2;
    final centerY = height ~/ 2;

    // Pave North-South & East-West avenues (width 3)
    for (int y = 2; y < height - 2; y++) {
      for (int dx = -1; dx <= 1; dx++) {
        tiles[y][centerX + dx] = TileType.floor;
      }
    }
    for (int x = 2; x < width - 2; x++) {
      for (int dy = -1; dy <= 1; dy++) {
        tiles[centerY + dy][x] = TileType.floor;
      }
    }

    // Pave large Central Plaza / Market Square
    for (int dy = -5; dy <= 5; dy++) {
      for (int dx = -5; dx <= 5; dx++) {
        tiles[centerY + dy][centerX + dx] = TileType.floor;
      }
    }

    // 2. Distinct Village Buildings & Shops (Rooms)
    final buildings = <Room>[
      // Town Square
      Room(0, centerX - 4, centerY - 4, 9, 9, type: RoomType.entryVestibule, name: 'Oakhaven Town Square', description: 'A bustling cobblestone plaza centered around an ornamental stone fountain, shaded by flowering elder trees.'),
      // Blacksmith's Forge (North-West)
      Room(1, 4, 4, 8, 7, type: RoomType.armory, name: 'Ironfang Blacksmith Forge', description: 'Heat radiates from roaring coal hearths. Heavy anvils, whetstones, and racks of tempered blades line the workshop.'),
      // Alchemist & Apothecary (North-East)
      Room(2, 21, 4, 8, 7, type: RoomType.alchemistLab, name: "Sylph's Mystic Apothecary", description: 'Bunches of lavender, wolfsbane, and chamomile hang drying from the ceiling beams over bubbling glassware.'),
      // The Boar's Tusk Tavern (South-West)
      Room(3, 4, 21, 9, 8, type: RoomType.ancientLibrary, name: "The Boar's Tusk Tavern", description: 'A lively timber inn rich with laughter, clinking pewter tankards, roasting spiced meat, and warm hearth glow.'),
      // Town Hall & Archives (South-East)
      Room(4, 21, 21, 8, 8, type: RoomType.shrineSanctum, name: 'Town Hall & Archives', description: 'Carved mahogany bookcases and municipal parchment records adorn the mayor’s stately civic chambers.'),
      // Gatehouse & Watchtower (North entry)
      Room(5, centerX - 4, 1, 9, 4, type: RoomType.bossChamber, name: 'North Palisade Gatehouse', description: 'Sturdy wooden parapets manned by the local watch garrison, guarding the road into Oakhaven.'),
    ];

    // Carve building interiors and place walls around them
    for (final b in buildings) {
      if (b.id == 0) continue; // Town square is an open plaza, not walled

      // 1. Build outer timber walls around building
      for (int dy = 0; dy < b.h; dy++) {
        for (int dx = 0; dx < b.w; dx++) {
          final x = b.x + dx;
          final y = b.y + dy;
          if (x >= 0 && x < width && y >= 0 && y < height) {
            final isBorder = dx == 0 || dx == b.w - 1 || dy == 0 || dy == b.h - 1;
            tiles[y][x] = isBorder ? TileType.wall : TileType.floor;
          }
        }
      }

      // 2. Add an entrance door facing towards the center streets
      final doorX = (b.x < centerX) ? (b.x + b.w - 1) : b.x;
      final doorY = b.centerY;
      if (doorX >= 0 && doorX < width && doorY >= 0 && doorY < height) {
        tiles[doorY][doorX] = TileType.door;
      }
    }

    // 3. Peripheral village perimeter wall & trees
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
          tiles[y][x] = TileType.wall;
        }
      }
    }

    return DungeonMap(
      tiles: tiles,
      rooms: buildings,
      entryPoint: Point(centerX, centerY),
      seed: seed,
      width: width,
      height: height,
    );
  }
}
