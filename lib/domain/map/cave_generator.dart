import 'dart:math';
import 'tile_types.dart';

/// Generates an organic subterranean cavern and cave network with irregular rock
/// chambers, subterranean water pools, glowing crystal grottos, and mining tunnels
/// with 3 distinct procedural layout archetypes for every seed.
class CaveGenerator {
  DungeonMap generate({required int seed, int width = 36, int height = 36}) {
    final rng = Random(seed);
    final layoutType = seed.abs() % 3;

    // Base layer: solid cavern rock walls
    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.wall));
    final rooms = <Room>[];

    if (layoutType == 0) {
      // -------------------------------------------------------------
      // Archetype 0: Subterranean Sunken Lake & Geode
      // -------------------------------------------------------------
      rooms.addAll([
        Room(0, 4, 4, 8, 8, type: RoomType.entryVestibule, name: 'Cavern Mouth Entry', description: 'A wide cavern vestibule where pale surface daylight gives way to damp stalactites and echoing subterranean dripline.'),
        Room(1, width - 13, 4, 9, 8, type: RoomType.shrineSanctum, name: 'Glimmering Crystal Geode', description: 'Towering clusters of prismatic azurite and amethyst crystals protrude from the cavern walls, emitting soothing ambient light.'),
        Room(2, 4, height - 13, 10, 9, type: RoomType.floodedCrypt, name: 'Subterranean Sunken Lake', description: 'A serene underground lagoon of glassy black water reflecting the phosphorescent algae on the soaring cavern ceiling.'),
        Room(3, width - 12, height - 13, 8, 8, type: RoomType.armory, name: 'Dwarven Mine Excavation', description: 'Abandoned wooden mine shaft pilings, ore tracks, and iron wheelbarrows left behind by prospecting dwarven miners.'),
        Room(4, 13, 13, 10, 9, type: RoomType.ancientLibrary, name: 'Echoing Chasm Crossing', description: 'A vast underground chamber bisected by a natural stone bridge spanning a fathomless shadowy fissure.'),
        Room(5, 13, height - 11, 9, 8, type: RoomType.bossChamber, name: 'Primordial Cavern Sanctum', description: 'An ancient subterranean altar surrounded by colossal stalactites and glowing mineral heat fissures.'),
      ]);

      // Carve organic elliptical chambers
      for (final r in rooms) {
        final cx = r.centerX;
        final cy = r.centerY;
        final rx = r.w / 2.0;
        final ry = r.h / 2.0;

        for (int y = r.y; y < r.y + r.h; y++) {
          for (int x = r.x; x < r.x + r.w; x++) {
            if (x <= 1 || y <= 1 || x >= width - 2 || y >= height - 2) continue;
            final dx = (x - cx) / rx;
            final dy = (y - cy) / ry;
            final distSq = dx * dx + dy * dy;
            final noise = (rng.nextDouble() - 0.5) * 0.35;
            if (distSq + noise <= 1.0) {
              tiles[y][x] = (r.id == 2 && distSq < 0.50) ? TileType.water : TileType.floor;
            }
          }
        }
      }

      // Connect chambers with winding organic tunnels
      for (int i = 1; i < rooms.length; i++) {
        _carveOrganicTunnel(tiles, rooms[i - 1].centerX, rooms[i - 1].centerY, rooms[i].centerX, rooms[i].centerY, rng, width, height);
      }
      _carveOrganicTunnel(tiles, rooms[0].centerX, rooms[0].centerY, rooms[4].centerX, rooms[4].centerY, rng, width, height);

    } else if (layoutType == 1) {
      // -------------------------------------------------------------
      // Archetype 1: Dwarven Abandoned Mine Labyrinth
      // -------------------------------------------------------------
      rooms.addAll([
        Room(0, width ~/ 2 - 4, 3, 8, 7, type: RoomType.entryVestibule, name: 'Mine Shaft Elevator Entry', description: 'Heavy timber headframe with winch cables descending into the dark dwarven mining depths.'),
        Room(1, 4, 11, 8, 8, type: RoomType.armory, name: 'Blast Powder Magazine', description: 'Dry stone chamber stacked with saltpeter casks and pickaxe bundles for breaking deep granite.'),
        Room(2, width - 12, 11, 8, 8, type: RoomType.ancientLibrary, name: 'Surveyor Cartography Vault', description: 'Drafting tables with parchment maps of veins of silver, mithral, and adamantine ore.'),
        Room(3, 4, height - 12, 8, 8, type: RoomType.treasureVault, name: 'Smelting Furnace Grotto', description: 'Extinguished iron smelters and slag troughs where raw ores were once cast into trade ingots.'),
        Room(4, width - 12, height - 12, 8, 8, type: RoomType.shrineSanctum, name: 'Shrine of the Mountain Father', description: 'Carved stone bust of the Dwarven All-Father surrounded by votive offering bowls.'),
        Room(5, width ~/ 2 - 5, height ~/ 2 - 4, 10, 9, type: RoomType.bossChamber, name: 'Deep Mithral Vein Quarry', description: 'A massive excavated amphitheater with shimmering veins of blue-silver mithral running through the rock.'),
      ]);

      for (final r in rooms) {
        for (int y = r.y; y < r.y + r.h; y++) {
          for (int x = r.x; x < r.x + r.w; x++) {
            if (x >= 2 && x < width - 2 && y >= 2 && y < height - 2) {
              tiles[y][x] = TileType.floor;
            }
          }
        }
      }

      // Connect with rectilinear mining tunnels (width 2)
      for (int i = 1; i < rooms.length; i++) {
        final a = rooms[i - 1];
        final b = rooms[i];
        _carveMineTunnel(tiles, a.centerX, a.centerY, b.centerX, b.centerY);
      }
      _carveMineTunnel(tiles, rooms[0].centerX, rooms[0].centerY, rooms[5].centerX, rooms[5].centerY);

    } else {
      // -------------------------------------------------------------
      // Archetype 2: Magma Fissure & Stalactite Caverns
      // -------------------------------------------------------------
      rooms.addAll([
        Room(0, 4, 4, 8, 7, type: RoomType.entryVestibule, name: 'Upper Cavern Ledge', description: 'A narrow rocky shelf overlooking a vast chasm where warm sulfurous drafts rise from the depths.'),
        Room(1, width - 12, 4, 8, 8, type: RoomType.alchemistLab, name: 'Sulfur Vent Cavern', description: 'Yellow-crusted mineral vents puffing warm steam and mineral salts.'),
        Room(2, 4, height - 12, 8, 8, type: RoomType.shrineSanctum, name: 'Bioluminescent Mushroom Hollow', description: 'Giant fungi caps glowing in soft cyan and lilac hues, casting ethereal shadows over mossy rocks.'),
        Room(3, width - 12, height - 12, 9, 8, type: RoomType.treasureVault, name: 'Obsidian Cache Grotto', description: 'Smooth, mirror-like black obsidian walls reflecting the golden gleam of an ancient buried coffer.'),
        Room(4, width ~/ 2 - 5, height ~/ 2 - 4, 11, 9, type: RoomType.bossChamber, name: 'Magma Caldera Crucible', description: 'A subterranean lava fissure with glowing molten rock bathing the high stalactites in crimson fire.'),
        Room(5, 13, height - 10, 8, 7, type: RoomType.floodedCrypt, name: 'Subterranean Thermal Spring', description: 'Steaming mineral-rich thermal waters bubbling up from deep tectonic fissures.'),
      ]);

      for (final r in rooms) {
        final cx = r.centerX;
        final cy = r.centerY;
        final rx = r.w / 2.0;
        final ry = r.h / 2.0;

        for (int y = r.y; y < r.y + r.h; y++) {
          for (int x = r.x; x < r.x + r.w; x++) {
            if (x <= 1 || y <= 1 || x >= width - 2 || y >= height - 2) continue;
            final dx = (x - cx) / rx;
            final dy = (y - cy) / ry;
            final distSq = dx * dx + dy * dy;
            final noise = (rng.nextDouble() - 0.5) * 0.4;
            if (distSq + noise <= 1.0) {
              tiles[y][x] = (r.id == 5 && distSq < 0.40) ? TileType.water : TileType.floor;
            }
          }
        }
      }

      for (int i = 1; i < rooms.length; i++) {
        _carveOrganicTunnel(tiles, rooms[i - 1].centerX, rooms[i - 1].centerY, rooms[i].centerX, rooms[i].centerY, rng, width, height);
      }
      _carveOrganicTunnel(tiles, rooms[0].centerX, rooms[0].centerY, rooms[4].centerX, rooms[4].centerY, rng, width, height);
    }

    // Perimeter boundary remains solid cavern wall
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
      if (curX >= 1 && curX < width - 1 && curY >= 1 && curY < height - 1) {
        tiles[curY][curX] = TileType.floor;
        // Widen tunnel organically
        if (rng.nextBool()) {
          final nx = curX + (rng.nextBool() ? 1 : -1);
          if (nx >= 1 && nx < width - 1) tiles[curY][nx] = TileType.floor;
        }
      }
      if (rng.nextBool()) {
        if (curX != x2) curX += (x2 > curX) ? 1 : -1;
      } else {
        if (curY != y2) curY += (y2 > curY) ? 1 : -1;
      }
    }
  }

  void _carveMineTunnel(List<List<TileType>> tiles, int x1, int y1, int x2, int y2) {
    int curX = x1;
    while (curX != x2) {
      tiles[y1][curX] = TileType.floor;
      tiles[y1 + 1][curX] = TileType.floor;
      curX += (x2 > curX) ? 1 : -1;
    }
    int curY = y1;
    while (curY != y2) {
      tiles[curY][x2] = TileType.floor;
      tiles[curY][x2 + 1] = TileType.floor;
      curY += (y2 > curY) ? 1 : -1;
    }
  }
}
