import 'tile_types.dart';

/// Generates a royal citadel and castle stronghold with stone battlements,
/// an outer moat, drawbridge, Grand Throne Room, Royal Banquet Hall,
/// Knights' Armory, High Wizard's Spire, and Treasury Vault with 3 procedural archetypes.
class CastleGenerator {
  DungeonMap generate({required int seed, int width = 36, int height = 36}) {
    final layoutType = seed.abs() % 3;

    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.floor));
    final centerX = width ~/ 2;
    final centerY = height ~/ 2;
    final castleHalls = <Room>[];

    if (layoutType == 0) {
      // -------------------------------------------------------------
      // Archetype 0: Moated Royal Citadel
      // -------------------------------------------------------------
      // Deep Water Moat around perimeter
      for (int y = 2; y < height - 2; y++) {
        for (int x = 2; x < width - 2; x++) {
          final isMoat = (y == 2 || y == 3 || y == height - 3 || y == height - 4 ||
                          x == 2 || x == 3 || x == width - 3 || x == width - 4);
          if (isMoat) {
            tiles[y][x] = TileType.water;
          }
        }
      }

      // Central Drawbridge crossing south moat into courtyard
      for (int y = height - 4; y <= height - 2; y++) {
        tiles[y][centerX - 1] = TileType.floor;
        tiles[y][centerX] = TileType.floor;
        tiles[y][centerX + 1] = TileType.floor;
      }

      // Outer Curtain Wall
      for (int y = 4; y < height - 4; y++) {
        for (int x = 4; x < width - 4; x++) {
          if (y == 4 || y == height - 5 || x == 4 || x == width - 5) {
            tiles[y][x] = TileType.wall;
          }
        }
      }

      // Grand Gatehouse Archway
      tiles[height - 5][centerX - 1] = TileType.door;
      tiles[height - 5][centerX] = TileType.door;
      tiles[height - 5][centerX + 1] = TileType.door;

      castleHalls.addAll([
        Room(0, centerX - 4, centerY - 5, 9, 11, type: RoomType.bossChamber, name: 'High Throne Room of the Crown', description: 'Soaring granite arches line a crimson velvet carpet leading up to the gilded Lion Throne of the realm.'),
        Room(1, 6, 6, 8, 8, type: RoomType.ancientLibrary, name: 'Royal Banquet & Feast Hall', description: 'Long carved oak feast tables, wrought-iron candelabras, and tapestries depicting legendary dragonslayers.'),
        Room(2, width - 14, 6, 8, 8, type: RoomType.shrineSanctum, name: "Arcane Spire & Wizard's Sanctum", description: 'Pulsing purple mana crystals, astral orreries, and ancient grimoires resting on brass reading stands.'),
        Room(3, 6, height - 14, 8, 8, type: RoomType.armory, name: "Kingsguard Armory & Foundry", description: 'Polished suits of full plate mail, crest-engraved shields, and racks of tempered halberds.'),
        Room(4, width - 14, height - 14, 8, 8, type: RoomType.treasureVault, name: 'Royal Treasury & Vault', description: 'Gilded strongboxes bound in dwarven steel holding imperial gold reserves and heirloom crown gems.'),
        Room(5, centerX - 4, height - 9, 9, 4, type: RoomType.entryVestibule, name: 'Courtyard Jousting Ground', description: 'Stone-paved muster ground where squires practice weapon drills under the fluttering royal pennants.'),
      ]);

    } else if (layoutType == 1) {
      // -------------------------------------------------------------
      // Archetype 1: Mountain Cliffside Bastion
      // -------------------------------------------------------------
      // North and East cliff walls (solid impassable rock)
      for (int y = 1; y < 5; y++) {
        for (int x = 1; x < width - 1; x++) {
          tiles[y][x] = TileType.wall;
        }
      }

      // Central Great Hall
      castleHalls.addAll([
        Room(0, centerX - 4, centerY - 4, 9, 9, type: RoomType.bossChamber, name: 'High Council Dais & Sovereign Seat', description: 'Carved out of solid mountain granite, an imposing hall lit by roaring hearths and hanging torch chandeliers.'),
        Room(1, 4, 6, 8, 8, type: RoomType.armory, name: 'Cliffside Barbican Foundry', description: 'Smelting furnaces and anvil blocks where fortress smiths forge heavy siege defenses.'),
        Room(2, width - 12, 6, 8, 8, type: RoomType.shrineSanctum, name: 'Mountain Overlook Observatory', description: 'A dizzying stone balcony looking out over miles of misty peaks and cloud-draped valleys.'),
        Room(3, 4, height - 11, 8, 8, type: RoomType.ancientLibrary, name: 'War Planning Chamber', description: 'A massive sand-table map of the continent surrounded by high generals and realm banners.'),
        Room(4, width - 12, height - 11, 8, 8, type: RoomType.treasureVault, name: 'Subterranean Vault of the Mountain', description: 'Deep mountain caverns converted into a fortified treasury for ancient dwarven artifacts.'),
        Room(5, centerX - 4, height - 6, 9, 4, type: RoomType.entryVestibule, name: 'Grand Barbican Gatehouse', description: 'Heavy portcullises reinforced with iron studs guarding the narrow zigzag mountain pass.'),
      ]);

    } else {
      // -------------------------------------------------------------
      // Archetype 2: Imperial Palace Stronghold
      // -------------------------------------------------------------
      // Central Grand Courtyard with Fountains
      castleHalls.addAll([
        Room(0, centerX - 4, 4, 9, 8, type: RoomType.bossChamber, name: 'Imperial Sun Throne Hall', description: 'Gleaming white limestone halls framed by golden laurels and the exalted seat of the Empire.'),
        Room(1, 4, 4, 8, 8, type: RoomType.shrineSanctum, name: 'Cathedral of Royal Blessings', description: 'Stained-glass clerestories casting rainbow patterns over marble crypts of ancient saints.'),
        Room(2, width - 12, 4, 8, 8, type: RoomType.ancientLibrary, name: 'Imperial Archivist Spire', description: 'Thousands of bound leather volumes cataloging the genealogies and spells of the royal dynasty.'),
        Room(3, 4, height - 11, 8, 8, type: RoomType.armory, name: 'Champion Jousting Barracks', description: 'Polished lances, heraldic tournament tabards, and armor repair anvils.'),
        Room(4, width - 12, height - 11, 8, 8, type: RoomType.treasureVault, name: 'Crown Jewel Vault', description: 'Heavy vault doors encasing jewel-encrusted scepters, diadems, and sacred chalices.'),
        Room(5, centerX - 5, centerY - 2, 11, 9, type: RoomType.entryVestibule, name: 'Imperial Palace Courtyard', description: 'A serene flagstone terrace centered around an ornamental marble lion fountain and fragrant cypress trees.'),
      ]);
    }

    // Carve walled rooms and doors
    for (final r in castleHalls) {
      if (r.id == 5) continue; // Courtyards remain open

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

      final doorX = (r.x < centerX) ? (r.x + r.w - 1) : r.x;
      final doorY = r.centerY;
      if (doorX >= 0 && doorX < width && doorY >= 0 && doorY < height) {
        tiles[doorY][doorX] = TileType.door;
      }
    }

    // Perimeter walls
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
      entryPoint: Point(centerX, centerY),
      seed: seed,
      width: width,
      height: height,
    );
  }
}
