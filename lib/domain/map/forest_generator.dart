import 'dart:math';
import 'tile_types.dart';

/// Generates an expansive outdoor forest & wilderness map featuring natural
/// clearings, winding dirt trails, river streams, wooden bridges, and tree groves
/// with 3 distinct procedural layout archetypes for every seed.
class ForestGenerator {
  DungeonMap generate({required int seed, int width = 36, int height = 36}) {
    final rng = Random(seed);
    final layoutType = seed.abs() % 3;

    final tiles = List.generate(height, (_) => List.generate(width, (_) => TileType.plains));
    final rooms = <Room>[];

    if (layoutType == 0) {
      // -------------------------------------------------------------
      // Archetype 0: River Valley Meander
      // -------------------------------------------------------------
      int riverX = width - 6 - rng.nextInt(6);
      for (int y = 0; y < height; y++) {
        riverX += rng.nextInt(3) - 1;
        riverX = riverX.clamp(4, width - 5);
        for (int rx = -1; rx <= 1; rx++) {
          final x = riverX + rx;
          if (x >= 0 && x < width) {
            tiles[y][x] = TileType.water;
          }
        }
      }

      rooms.addAll([
        Room(0, 4, 4, 7, 7, type: RoomType.entryVestibule, name: 'Ranger Trailhead Clearing', description: 'Sunlight filters through towering evergreens onto a peaceful mossy clearing where the forest path begins.'),
        Room(1, 15, 4, 8, 7, type: RoomType.shrineSanctum, name: 'Ancient Druid Grove', description: 'Ancient moss-covered menhirs circle an illuminated stone altar resonating with the heartbeat of the wilds.'),
        Room(2, 4, 16, 8, 7, type: RoomType.ancientLibrary, name: 'Hermit Sage Encampment', description: 'A cozy hollow flanked by aged willows, featuring a warm campfire ring and drying herbal medicine racks.'),
        Room(3, 22, 14, 7, 7, type: RoomType.armory, name: 'Woodcutter Timber Yard', description: 'Stacked pine timber and sturdy split logs surround an active timber workshop under the trees.'),
        Room(4, 7, 25, 8, 6, type: RoomType.treasureVault, name: 'Sunken Brook Clearing', description: 'A tranquil riverbank glade where crystal-clear water pools against smooth river stones and wild ferns.'),
        Room(5, 23, 24, 7, 7, type: RoomType.bossChamber, name: 'Wolf Crag Overlook', description: 'A rugged plateau crowned with granite boulders, overlooking the sweeping expanse of the ancient woodland.'),
        Room(6, width - 11, 4, 6, 6, type: RoomType.alchemistLab, name: 'Fairy Mushroom Glade', description: 'Bioluminescent fungal spores drift lazily over damp moss and ancient fallen birch logs.'),
        Room(7, 14, 16, 6, 6, type: RoomType.shrineSanctum, name: 'Faerie Ring Meadow', description: 'A circle of luminescent blue toadstools humming with playful fey enchantment.'),
        Room(8, 15, 25, 6, 6, type: RoomType.armory, name: 'Ranger Archery Glade', description: 'Straw archery targets and wooden bowyer benches sheltered under birch trees.'),
        Room(9, width - 11, 14, 6, 6, type: RoomType.treasureVault, name: 'Whispering Hollow Cache', description: 'An ancient hollow oak trunk where woodland rangers cache emergency supplies.'),
        Room(10, width - 11, 24, 6, 6, type: RoomType.ancientLibrary, name: 'Wildflower Clearing', description: 'Carpeted with purple heather, wild chamomile, and golden arnica blossoms.'),
      ]);

    } else if (layoutType == 1) {
      // -------------------------------------------------------------
      // Archetype 1: Giant Redwood Hollow (Expansive Woodland Clearings)
      // -------------------------------------------------------------
      final cx = width ~/ 2;
      final cy = height ~/ 2;

      rooms.addAll([
        Room(0, cx - 4, cy - 4, 9, 9, type: RoomType.entryVestibule, name: 'Great Heart Tree Clearing', description: 'A colossal ancient redwood with radiant emerald leaves dominates this tranquil sacred clearing.'),
        Room(1, 4, 4, 8, 7, type: RoomType.shrineSanctum, name: 'Standing Stones Circle', description: 'Weathered megaliths inscribed with spiral constellations humming with ambient planar magic.'),
        Room(2, width - 12, 4, 8, 7, type: RoomType.alchemistLab, name: 'Moonwell Hollow', description: 'A silver reflecting pool fed by an underground spring where starlight gathers even at midday.'),
        Room(3, 4, height - 11, 8, 7, type: RoomType.ancientLibrary, name: 'Elven Watchtower Ruins', description: 'Crumbling white marble pillars wrapped in ivy, remnants of an ancient woodland observation post.'),
        Room(4, width - 12, height - 11, 8, 7, type: RoomType.bossChamber, name: 'Ancient Stag Ridge', description: 'An elevated mossy bluff overlooking the sweeping expanse of the ancient forest canopy.'),
        Room(5, 4, cy - 3, 7, 7, type: RoomType.armory, name: 'Hunter Lodging Glade', description: 'Canvas lean-to tents, archery targets, and racks of seasoned ash wood longbows.'),
        Room(6, width - 11, cy - 3, 7, 7, type: RoomType.treasureVault, name: 'Hidden Briar Grotto', description: 'Tangled blackberry brambles protecting an ancient stone cache buried beneath elder roots.'),
        Room(7, cx - 11, 4, 6, 6, type: RoomType.ancientLibrary, name: 'Ancient Moss Menhirs', description: 'Carved runic pillars half-swallowed by emerald moss and creeping vines.'),
        Room(8, cx + 5, 4, 6, 6, type: RoomType.treasureVault, name: 'Silver Leaf Grove', description: 'Shimmering white bark birch trees shedding leaves of spun silver.'),
        Room(9, cx - 11, height - 11, 6, 6, type: RoomType.shrineSanctum, name: 'Druidic Sun Shrine', description: 'Carved solar disk resting atop an ivy-woven stone pedestal.'),
        Room(10, cx + 5, height - 11, 6, 6, type: RoomType.armory, name: 'Woodland Trapper Outpost', description: 'Tanned deer hides, cedar drying racks, and hand-forged animal snares.'),
      ]);

    } else {
      // -------------------------------------------------------------
      // Archetype 2: Twin Brooks & Wetland Glade
      // -------------------------------------------------------------
      for (int x = 0; x < width; x++) {
        final y1 = (height * 0.35 + sin(x / 4.0) * 2.5).round().clamp(2, height - 3);
        final y2 = (height * 0.70 + cos(x / 5.0) * 2.5).round().clamp(2, height - 3);
        tiles[y1][x] = TileType.water;
        tiles[y2][x] = TileType.water;
      }

      rooms.addAll([
        Room(0, 4, 3, 7, 7, type: RoomType.entryVestibule, name: 'River Crossing Trailhead', description: 'Gentle rushing water cascades over smooth river pebbles, framed by flowering elderberry shrubs.'),
        Room(1, 16, 3, 8, 7, type: RoomType.shrineSanctum, name: 'Willow Shaded Spring', description: 'A crystal-clear spring welling up beneath the weeping branches of a colossal willow tree.'),
        Room(2, 4, 15, 8, 6, type: RoomType.ancientLibrary, name: 'Island Sanctuary Camp', description: 'A dry islet between the brooks featuring a warm stone fire pit and dried herbs.'),
        Room(3, 20, 15, 8, 6, type: RoomType.armory, name: 'Beaver Dam Crossing', description: 'Sturdy interlocking timber and river stones forming a natural crossing point over the brook.'),
        Room(4, 5, 26, 8, 6, type: RoomType.treasureVault, name: 'Sunken Lotus Marsh', description: 'Floating water lilies with luminescent petals surrounded by quiet reeds and dragonflies.'),
        Room(5, 21, 25, 8, 7, type: RoomType.bossChamber, name: 'Bog Wyrm Hollow', description: 'A shadowed depression flanked by twisted cypress roots and ancient mossy stones.'),
        Room(6, width - 11, 4, 7, 7, type: RoomType.alchemistLab, name: 'Herbalist Drying Glade', description: 'Racks of wild thyme, yarrow, and coltsfoot drying in the sunlit breeze.'),
        Room(7, width - 11, 15, 6, 6, type: RoomType.treasureVault, name: 'Sunken Pearl Grotto', description: 'Gentle shallows hiding freshwater mussels with shimmering wild pearls.'),
        Room(8, 13, 10, 6, 5, type: RoomType.ancientLibrary, name: 'Elder Wood Bridge Camp', description: 'A cozy timber campsite watching over the river crossing.'),
        Room(9, 13, 20, 6, 5, type: RoomType.shrineSanctum, name: 'Water Nymph Pool', description: 'Crystal-clear azure water where luminous dragonflies dance.'),
        Room(10, width - 11, 25, 6, 6, type: RoomType.armory, name: 'Ranger Lookout Bluff', description: 'An elevated wooden observation platform perched in a colossal pine.'),
      ]);
    }

    // Carve open grass/plains in all rooms
    for (final r in rooms) {
      for (int dy = 0; dy < r.h; dy++) {
        for (int dx = 0; dx < r.w; dx++) {
          final x = r.x + dx;
          final y = r.y + dy;
          if (x >= 0 && x < width && y >= 0 && y < height) {
            tiles[y][x] = TileType.plains;
          }
        }
      }
    }

    // Connect rooms with winding dirt pathways
    for (int i = 1; i < rooms.length; i++) {
      final a = rooms[i - 1];
      final b = rooms[i];
      _carveWindingTrail(tiles, a.centerX, a.centerY, b.centerX, b.centerY, rng);
    }
    _carveWindingTrail(tiles, rooms.last.centerX, rooms.last.centerY, rooms.first.centerX, rooms.first.centerY, rng);

    // Wooden Footbridges across rivers where paths cross water
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (tiles[y][x] == TileType.water) {
          final hasPathW = tiles[y][x - 1] == TileType.floor;
          final hasPathE = tiles[y][x + 1] == TileType.floor;
          final hasPathN = tiles[y - 1][x] == TileType.floor;
          final hasPathS = tiles[y + 1][x] == TileType.floor;
          if ((hasPathW && hasPathE) || (hasPathN && hasPathS)) {
            tiles[y][x] = TileType.floor; // Wooden bridge planking
          }
        }
      }
    }

    // Populate outer dense forest borders & tree clusters with TileType.wall (renders as 3D canopy trees!)
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
          tiles[y][x] = TileType.wall;
          continue;
        }
        if (tiles[y][x] == TileType.water || tiles[y][x] == TileType.floor) continue;

        bool inRoom = false;
        for (final r in rooms) {
          if (r.contains(Point(x, y))) {
            inRoom = true;
            break;
          }
        }
        if (!inRoom) {
          final treeChance = (x < 3 || x > width - 4 || y < 3 || y > height - 4) ? 0.75 : 0.38;
          if (rng.nextDouble() < treeChance) {
            tiles[y][x] = TileType.wall;
          }
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

  void _carveWindingTrail(List<List<TileType>> tiles, int x1, int y1, int x2, int y2, Random rng) {
    int curX = x1;
    int curY = y1;
    while (curX != x2 || curY != y2) {
      if (tiles[curY][curX] != TileType.water) {
        tiles[curY][curX] = TileType.floor;
      }
      if (rng.nextBool()) {
        if (curX != x2) curX += (x2 > curX) ? 1 : -1;
      } else {
        if (curY != y2) curY += (y2 > curY) ? 1 : -1;
      }
    }
  }
}
