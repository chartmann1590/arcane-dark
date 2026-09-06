import 'dart:math';
import 'tile_types.dart';

/// Generates a sprawling medieval fantasy metropolis with grand paved boulevards,
/// central market bazaar plaza, canal waterways, footbridges, and prominent districts
/// with 3 distinct procedural layout archetypes for every seed.
class CityGenerator {
  DungeonMap generate({required int seed, int width = 36, int height = 36}) {
    final rng = Random(seed);
    final layoutType = seed.abs() % 3;

    // Base layer: dressed limestone street paving
    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.floor));

    final centerX = width ~/ 2;
    final centerY = height ~/ 2;
    final districts = <Room>[];

    if (layoutType == 0) {
      // -------------------------------------------------------------
      // Archetype 0: Canal Venice Metropolis
      // -------------------------------------------------------------
      const canalX = 27;
      for (int y = 1; y < height - 1; y++) {
        for (int dx = 0; dx <= 2; dx++) {
          tiles[y][canalX + dx] = TileType.water;
        }
      }

      // Stone footbridges crossing the canal
      final bridgeYs = [9, 18, 27];
      for (final by in bridgeYs) {
        for (int dx = 0; dx <= 2; dx++) {
          tiles[by][canalX + dx] = TileType.floor;
        }
      }

      // Central Market Plaza
      for (int dy = -6; dy <= 6; dy++) {
        for (int dx = -6; dx <= 6; dx++) {
          tiles[centerY + dy][centerX + dx] = TileType.floor;
        }
      }

      districts.addAll([
        Room(0, centerX - 5, centerY - 5, 11, 11, type: RoomType.entryVestibule, name: 'Grand Market Bazaar', description: 'A roaring metropolis marketplace filled with vibrant silk canopies, exotic spice merchants, gem traders, and street entertainers.'),
        Room(1, 3, 3, 9, 8, type: RoomType.bossChamber, name: "High Citadel & Governor's Palace", description: 'Polished white marble columns, majestic stained-glass clerestories, and the gilded seat of the City Magistrate.'),
        Room(2, centerX + 4, 3, 8, 8, type: RoomType.shrineSanctum, name: 'Grand Cathedral of the Sun', description: 'Sunlight streams through vaulted gold-leaf arches onto sacred altars, where high clerics chant solemn hymns of warding.'),
        Room(3, 3, centerY + 3, 9, 8, type: RoomType.armory, name: 'City Watch Barracks & Armory', description: 'Heavy oak weapon racks, rows of polished steel breastplates, target dummies, and holding cells for lawbreakers.'),
        Room(4, centerX + 4, centerY + 3, 8, 8, type: RoomType.ancientLibrary, name: 'Harbor Guild & Trade Vaults', description: 'Stacks of ledger books, navigation astrolabes, sealed crates of overseas spices, and chests of trade ingots.'),
        Room(5, canalX + 3, 14, 5, 8, type: RoomType.floodedCrypt, name: 'Canal Water Gate & Docks', description: 'Mooring posts, coiled mooring ropes, and freight skiffs transporting goods through the city canals.'),
        Room(6, 13, 3, 7, 7, type: RoomType.alchemistLab, name: 'Arcane Artificer Academy', description: 'Gears, glowing astrolabes, and brass automatons buzzing with concentrated arcane lightning.'),
      ]);

    } else if (layoutType == 1) {
      // -------------------------------------------------------------
      // Archetype 1: Radial Imperial Citadel
      // -------------------------------------------------------------
      // Circular Plaza in the center
      for (int dy = -7; dy <= 7; dy++) {
        for (int dx = -7; dx <= 7; dx++) {
          if (dx * dx + dy * dy <= 49) {
            tiles[centerY + dy][centerX + dx] = TileType.floor;
          }
        }
      }

      // Radiating Avenues
      for (int i = 2; i < width - 2; i++) {
        tiles[centerY][i] = TileType.floor;
        tiles[centerY - 1][i] = TileType.floor;
        tiles[centerY + 1][i] = TileType.floor;
        tiles[i][centerX] = TileType.floor;
        tiles[i][centerX - 1] = TileType.floor;
        tiles[i][centerX + 1] = TileType.floor;
      }

      districts.addAll([
        Room(0, centerX - 4, centerY - 4, 9, 9, type: RoomType.entryVestibule, name: 'Imperial Sun Plaza', description: 'A massive circular forum ringed with white marble statuary, roaring fountains, and silk vendor pavilions.'),
        Room(1, 3, 3, 9, 8, type: RoomType.bossChamber, name: 'Imperial Council Senate', description: 'A grand semicircular legislative hall with crimson velvet benches and the eagle standard of the Empire.'),
        Room(2, width - 12, 3, 9, 8, type: RoomType.shrineSanctum, name: 'Temple of the Astral Light', description: 'Soaring spires adorned with silver bells, radiating restorative divine luminescence across the promenade.'),
        Room(3, 3, height - 11, 9, 8, type: RoomType.armory, name: 'Praetorian Guard Foundry', description: 'Massive iron forges producing gilded knightly plate mail and masterwork tower shields.'),
        Room(4, width - 12, height - 11, 9, 8, type: RoomType.ancientLibrary, name: 'Grand Imperial Athenaeum', description: 'Centuries of historical codices, star charts, and planar maps housed in three tiers of mahogany shelving.'),
        Room(5, centerX - 4, 2, 9, 4, type: RoomType.bossChamber, name: 'North Imperial Gatehouse', description: 'Colossal stone archway guarded by armored halberdiers and enchanted ballistae.'),
        Room(6, centerX - 4, height - 6, 9, 4, type: RoomType.bossChamber, name: 'South Victory Gatehouse', description: 'Granite triumphal gate celebrating historic realm victories, draped in golden battle flags.'),
      ]);

    } else {
      // -------------------------------------------------------------
      // Archetype 2: Riverfront Port Harbor
      // -------------------------------------------------------------
      // Horizontal River along the North quarter (y = 5..8)
      for (int x = 1; x < width - 1; x++) {
        tiles[5][x] = TileType.water;
        tiles[6][x] = TileType.water;
        tiles[7][x] = TileType.water;
      }

      // Stone bridges over river at x = 8, x = 18, x = 28
      final bridgeXs = [8, 18, 28];
      for (final bx in bridgeXs) {
        for (int y = 5; y <= 7; y++) {
          tiles[y][bx] = TileType.floor;
          tiles[y][bx + 1] = TileType.floor;
        }
      }

      districts.addAll([
        Room(0, centerX - 5, centerY - 4, 11, 9, type: RoomType.entryVestibule, name: 'Harborside Trade Promenade', description: 'A wide open cobblestone waterfront plaza filled with sailors, spices, fishmongers, and maritime traders.'),
        Room(1, 3, 9, 9, 8, type: RoomType.armory, name: 'Waterfront Marine Bastion', description: 'Iron-gated harbor garrison protecting cargo ships from buccaneers and river monsters.'),
        Room(2, width - 12, 9, 9, 8, type: RoomType.shrineSanctum, name: 'Seafarer Shrine of the Waves', description: 'Altar adorned with mother-of-pearl, whalebone, and eternal blue flame offering blessings of safe voyage.'),
        Room(3, 3, height - 11, 9, 8, type: RoomType.ancientLibrary, name: 'Admiralty Cartography Guild', description: 'Sea charts, sextants, and sealed journals of deep ocean navigation and kraken sightings.'),
        Room(4, width - 12, height - 11, 9, 8, type: RoomType.bossChamber, name: 'Harbormaster Customs Hall', description: 'The official inspection office assessing ship manifests and stamping royal trade permits.'),
        Room(5, centerX - 4, 1, 9, 4, type: RoomType.floodedCrypt, name: 'North River Cargo Wharf', description: 'Moored skiffs unloading cargo casks of wine, grain, and iron ores directly onto stone quays.'),
        Room(6, centerX - 4, height - 6, 9, 4, type: RoomType.alchemistLab, name: 'Apothecary Guildhouse', description: 'Specializing in rare overseas herbs, tropical antivenoms, and volatile alchemical fire.'),
      ]);
    }

    // Carve walled structures around buildings (skipping open plazas and docks)
    for (final d in districts) {
      if (d.id == 0) continue; // Plaza is open
      if (d.id == 5 && (layoutType == 0 || layoutType == 2)) continue; // Docks are open waterfront

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

    // Outer City Defensive Stone Walls & Perimeter Gates
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
