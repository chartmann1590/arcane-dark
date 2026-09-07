import 'dart:math';
import 'tile_types.dart';

/// Generates a richly detailed medieval/fantasy village and township map with
/// completely distinct procedural layouts for every seed:
/// 1. River Valley Township (River dividing township, arched footbridges, watermill)
/// 2. Hilltop Citadel Village (Terraced avenues, concentric stone squares, orchard knolls)
/// 3. Crossroads Market Haven (Diagonal thoroughfares, sprawling bazaar, cottage quarters)
class VillageGenerator {
  DungeonMap generate({required int seed, int width = 36, int height = 36}) {
    final rng = Random(seed);
    final layoutType = seed.abs() % 3;

    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.plains));
    final buildings = <Room>[];
    Point entryPoint = Point(width ~/ 2, height ~/ 2);

    if (layoutType == 0) {
      // -------------------------------------------------------------
      // Archetype 0: River Valley Township
      // -------------------------------------------------------------
      // 1. Natural Winding River through the village (East-West or North-South)
      final riverTiles = <Point>{};
      int riverMid = height ~/ 2 + 2;
      for (int x = 0; x < width; x++) {
        riverMid += (rng.nextInt(3) - 1);
        riverMid = riverMid.clamp(height ~/ 2 - 3, height ~/ 2 + 4);
        for (int dy = -1; dy <= 1; dy++) {
          final y = riverMid + dy;
          if (y >= 0 && y < height) {
            tiles[y][x] = TileType.water;
            riverTiles.add(Point(x, y));
          }
        }
      }

      // Stone footbridges crossing the river
      final bridgeXs = [width ~/ 4, width ~/ 2, (width * 3) ~/ 4];
      for (final bx in bridgeXs) {
        for (int y = 0; y < height; y++) {
          if (tiles[y][bx] == TileType.water) {
            tiles[y][bx] = TileType.floor;
            if (bx + 1 < width) tiles[y][bx + 1] = TileType.floor;
          }
        }
      }

      // Main North-South Avenues crossing bridges
      for (final bx in bridgeXs) {
        for (int y = 2; y < height - 2; y++) {
          tiles[y][bx] = TileType.floor;
        }
      }

      // North bank road & South bank road
      for (int x = 3; x < width - 3; x++) {
        tiles[8][x] = TileType.floor;
        tiles[height - 8][x] = TileType.floor;
      }

      // Central Riverfront Market Plaza (North Bank)
      final cx = width ~/ 2;
      for (int dy = -3; dy <= 2; dy++) {
        for (int dx = -4; dx <= 4; dx++) {
          final y = 11 + dy;
          final x = cx + dx;
          if (tiles[y][x] != TileType.water) tiles[y][x] = TileType.floor;
        }
      }

      entryPoint = Point(cx, 11);

      buildings.addAll([
        Room(0, cx - 4, 8, 9, 6, type: RoomType.entryVestibule, name: 'Riverfront Market Plaza', description: 'A lively cobblestone square on the riverbank lined with colorful merchant canopies and an ancient stone fountain.'),
        Room(1, 3, 3, 7, 5, type: RoomType.armory, name: 'Ironfang Blacksmith & Foundry', description: 'Roaring charcoal hearths and ringing anvils where master dwarven smiths temper fine steel.'),
        Room(2, cx + 5, 3, 7, 5, type: RoomType.alchemistLab, name: "Sylph's Mystic Apothecary", description: 'Aromatic drying bundles of lavender and wolfsbane hanging above bubbling glassware and herb pots.'),
        Room(3, 3, height - 8, 8, 6, type: RoomType.ancientLibrary, name: "The Boar's Tusk Tavern", description: 'A warm two-story timber tavern filled with hearty laughter, roasted boar on the spit, and foaming cider kegs.'),
        Room(4, cx - 4, height - 8, 9, 6, type: RoomType.shrineSanctum, name: 'Town Hall & Archives', description: 'Stately municipal council chamber adorned with realm charters, oak archives, and velvet flags.'),
        Room(5, cx - 3, 1, 7, 3, type: RoomType.bossChamber, name: 'North Palisade Gatehouse', description: 'Heavy timber watchtowers guarding the King’s Highway road entering Oakhaven.'),
        Room(6, width - 10, height - 8, 7, 5, type: RoomType.treasureVault, name: 'Gwen’s Bakery & Mill', description: 'Fresh golden loaves of honey-oat bread cooling beside watermill flour sacks.'),
        Room(7, width - 10, 3, 7, 5, type: RoomType.ancientLibrary, name: "Woodcutter's Lodge", description: 'Stacked cedar timber, split firewood piles, and woodworking benches in a tranquil grove.'),
        Room(8, 12, height - 14, 6, 5, type: RoomType.entryVestibule, name: 'River Weaver Cottage', description: 'A cozy thatched-roof cottage with flowerbeds, weaving looms, and colorful woven tapestries.'),
        Room(9, width - 12, 14, 6, 5, type: RoomType.entryVestibule, name: "Fisherman's Wharf Homestead", description: 'Drying fishing nets, willow fish traps, and a stone chimney puffing fragrant woodsmoke.'),
        Room(10, 3, 11, 6, 5, type: RoomType.ancientLibrary, name: "Miller's Granary & Grain Store", description: 'Sacks of milled barley, spelt, and golden grain guarded by watchful barn owls.'),
        Room(11, width - 9, height - 15, 6, 5, type: RoomType.shrineSanctum, name: "Chapel of the Sacred Grove", description: 'A quiet sunlit sanctuary with stained-glass depictions of the Silver Maiden.'),
        Room(12, 12, 3, 6, 4, type: RoomType.armory, name: "Fletcher & Archery Yard", description: 'Seasoned ash wood recurve bows and feathered goose quills drying on racks.'),
      ]);

    } else if (layoutType == 1) {
      // -------------------------------------------------------------
      // Archetype 1: Hilltop Citadel Village
      // -------------------------------------------------------------
      final cx = width ~/ 2;
      final cy = height ~/ 2;
      entryPoint = Point(cx, cy);

      // Pave Circular Concentric Cobblestone Rings
      for (int r = 4; r <= 13; r += 4) {
        for (int angleDeg = 0; angleDeg < 360; angleDeg += 3) {
          final rad = angleDeg * pi / 180;
          final px = (cx + r * cos(rad)).round();
          final py = (cy + r * sin(rad) * 0.85).round();
          if (px >= 2 && px < width - 2 && py >= 2 && py < height - 2) {
            tiles[py][px] = TileType.floor;
          }
        }
      }

      // Cross spokes
      for (int i = 3; i < width - 3; i++) {
        tiles[cy][i] = TileType.floor;
      }
      for (int i = 3; i < height - 3; i++) {
        tiles[i][cx] = TileType.floor;
      }

      // Central Hilltop Commons Plaza (6x6)
      for (int dy = -3; dy <= 3; dy++) {
        for (int dx = -3; dx <= 3; dx++) {
          tiles[cy + dy][cx + dx] = TileType.floor;
        }
      }

      buildings.addAll([
        Room(0, cx - 3, cy - 3, 7, 7, type: RoomType.entryVestibule, name: 'High Town Commons & Obelisk', description: 'The elevated crown of Oakhaven, featuring an ancient marble sundial obelisk and flowering cherry trees.'),
        Room(1, 4, 4, 8, 6, type: RoomType.armory, name: 'Sunken Forge Armory', description: 'Sheltered stone armory built into the hillside with glowing forge fires and iron plating racks.'),
        Room(2, width - 12, 4, 8, 6, type: RoomType.alchemistLab, name: 'Sunward Apothecary Greenhouse', description: 'Glass-paneled greenhouse nurturing rare desert sage and luminous cave moss.'),
        Room(3, 4, height - 10, 8, 6, type: RoomType.ancientLibrary, name: 'The Rusty Lantern Inn', description: 'Cozy hillside tavern with private booths, roaring hearth fireplace, and local elderberry wine.'),
        Room(4, width - 12, height - 10, 8, 6, type: RoomType.shrineSanctum, name: 'High Magistrate Court', description: 'Granite hall where local disputes are arbitrated under the seal of the realm magistrate.'),
        Room(5, cx - 3, 1, 7, 3, type: RoomType.bossChamber, name: 'Hillside Watch Bastion', description: 'Elevated parapet overlooking the winding approach road, equipped with signaling beacons.'),
        Room(6, cx + 5, cy - 3, 6, 6, type: RoomType.treasureVault, name: 'Hillcrest Bakery & Granary', description: 'Clay ovens churning out warm buns, alongside barrels of ground barley and spelt.'),
        Room(7, cx - 11, cy - 3, 6, 6, type: RoomType.entryVestibule, name: 'Stonecutter Cottage', description: 'A sturdy granite cottage flanked by chisels, stone urns, and flowering moss gardens.'),
        Room(8, cx - 3, height - 5, 7, 3, type: RoomType.bossChamber, name: 'South Palisade Gate', description: 'Timber barricade gate opening into the verdant provincial pasturelands.'),
        Room(9, 4, cy - 3, 6, 6, type: RoomType.treasureVault, name: "Stonemason Guild Workshop", description: 'Chiseled marble blocks, gargoyles, and ornamental fountains awaiting placement.'),
        Room(10, cx + 5, height - 10, 6, 6, type: RoomType.alchemistLab, name: "Candle & Soap Works", description: 'Fragrant blocks of beeswax and lavender-infused soap cakes drying in willow trays.'),
        Room(11, cx - 11, height - 10, 6, 6, type: RoomType.ancientLibrary, name: "Hillside Herbal Tea House", description: 'Steaming samovars, private curtained booths, and rare floral tisanes.'),
      ]);

    } else {
      // -------------------------------------------------------------
      // Archetype 2: Crossroads Market Haven
      // -------------------------------------------------------------
      final cx = width ~/ 2;
      final cy = height ~/ 2;
      entryPoint = Point(cx, cy);

      // Broad Diagonal & Orthogonal Roads
      for (int i = 2; i < width - 2; i++) {
        tiles[cy][i] = TileType.floor;
        tiles[cy - 1][i] = TileType.floor;
        tiles[i][cx] = TileType.floor;
        tiles[i][cx - 1] = TileType.floor;
      }

      // Grand Oval Market Bazaar in the center
      for (int dy = -5; dy <= 5; dy++) {
        for (int dx = -5; dx <= 5; dx++) {
          if ((dx * dx) / 25.0 + (dy * dy) / 25.0 <= 1.0) {
            tiles[cy + dy][cx + dx] = TileType.floor;
          }
        }
      }

      buildings.addAll([
        Room(0, cx - 4, cy - 4, 9, 9, type: RoomType.entryVestibule, name: 'Crossroads Grand Bazaar', description: 'A bustling crossroads marketplace crowded with silk merchant canopies, fruit wagons, and musicians.'),
        Room(1, 3, 3, 8, 6, type: RoomType.armory, name: 'Crossroads Smithy & Wheelwright', description: 'Furnished workshop repairing cart wheels, shoeing horses, and forging battle-tested steel blades.'),
        Room(2, width - 11, 3, 8, 6, type: RoomType.alchemistLab, name: 'Mystic Herbal Dispensary', description: 'Glass alembics, drying roots, and herbal healing salves prepared by local apothecary masters.'),
        Room(3, 3, height - 9, 8, 6, type: RoomType.ancientLibrary, name: 'The Wayfarer Tavern & Stables', description: 'A boisterous trade tavern frequented by caravan merchants, bards, and roving adventurers.'),
        Room(4, width - 11, height - 9, 8, 6, type: RoomType.shrineSanctum, name: 'Village Guildhall & Registry', description: 'Parchment maps, caravan bounties, and trade contracts cataloged in heavy oak chests.'),
        Room(5, cx - 3, 1, 7, 3, type: RoomType.bossChamber, name: 'North Toll Gatehouse', description: 'Garrison station collecting tariffs and verifying adventurer credentials for the capital road.'),
        Room(6, 12, 4, 6, 5, type: RoomType.treasureVault, name: 'Sweetbriar Cottage & Bakery', description: 'A picturesque cottage draped in honeysuckle, smelling of fresh bread and berry pies.'),
        Room(7, width - 9, 12, 6, 6, type: RoomType.ancientLibrary, name: 'Tanner & Leatherworker Guild', description: 'Supple dragonleather boots, cured cowhide saddles, and reinforced leather jerkins.'),
        Room(8, 12, height - 9, 6, 5, type: RoomType.entryVestibule, name: 'Farmer Hodge’s Homestead', description: 'Charming farmstead cottage with stone well, pumpkin patches, and a thatched roof.'),
        Room(9, width - 11, cy - 3, 6, 6, type: RoomType.entryVestibule, name: 'Merchant Caravanserai', description: 'Resting quarters for traveling silk and gem traders displaying rare wares from afar.'),
        Room(10, 3, cy - 3, 6, 6, type: RoomType.treasureVault, name: "Silversmith & Trinket Vault", description: 'Glass display cases gleaming with filigree silver brooches and moonstone amulets.'),
        Room(11, cx + 5, 4, 6, 5, type: RoomType.alchemistLab, name: "Alchemist Glassblowing Studio", description: 'Muffled furnaces, blowing rods, and crystalline retorts glowing with magical tincture.'),
        Room(12, cx + 5, height - 9, 6, 5, type: RoomType.ancientLibrary, name: "Cartographer & Scribe Emporium", description: 'Inked regional charts, star maps, and rolls of vellum tied with silk ribbon.'),
      ]);
    }

    // Carve building interiors and place walls around them
    for (final b in buildings) {
      if (b.id == 0) continue; // Plaza is open, not walled

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

      // Add entrance doorway facing toward center streets
      final doorX = (b.x < entryPoint.x) ? (b.x + b.w - 1) : b.x;
      final doorY = b.centerY;
      if (doorX >= 0 && doorX < width && doorY >= 0 && doorY < height) {
        tiles[doorY][doorX] = TileType.door;
      }
    }

    // Outer Village Palisade & Perimeter Wall
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
      entryPoint: entryPoint,
      seed: seed,
      width: width,
      height: height,
    );
  }
}
