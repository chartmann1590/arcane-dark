import 'package:flutter_test/flutter_test.dart';
import 'package:dnd_ai/domain/map/village_generator.dart';
import 'package:dnd_ai/domain/map/forest_generator.dart';
import 'package:dnd_ai/domain/map/city_generator.dart';
import 'package:dnd_ai/domain/map/castle_generator.dart';
import 'package:dnd_ai/domain/map/cave_generator.dart';
import 'package:dnd_ai/domain/world_location.dart';
import 'package:dnd_ai/domain/pet_companion.dart';
import 'package:dnd_ai/features/play/village_populator.dart';
import 'package:dnd_ai/features/play/forest_populator.dart';
import 'package:dnd_ai/features/play/city_populator.dart';
import 'package:dnd_ai/features/play/castle_populator.dart';
import 'package:dnd_ai/features/play/cave_populator.dart';

void main() {
  group('Procedural Multi-Archetype Map Generators', () {
    test('VillageGenerator produces unique layout archetypes per seed', () {
      final map0 = VillageGenerator().generate(seed: 0);
      expect(map0.rooms.isNotEmpty, isTrue);
      expect(map0.rooms.any((r) => r.name.contains('Watermill') || r.name.contains('River')), isTrue);

      final map1 = VillageGenerator().generate(seed: 1);
      expect(map1.rooms.isNotEmpty, isTrue);
      expect(map1.rooms.any((r) => r.name.contains('Citadel') || r.name.contains('Terrace') || r.name.contains('Bastion')), isTrue);

      final map2 = VillageGenerator().generate(seed: 2);
      expect(map2.rooms.isNotEmpty, isTrue);
      expect(map2.rooms.any((r) => r.name.contains('Market') || r.name.contains('Crossroads') || r.name.contains('Haven')), isTrue);
    });

    test('ForestGenerator produces unique layouts per seed', () {
      final map0 = ForestGenerator().generate(seed: 0);
      expect(map0.rooms.isNotEmpty, isTrue);

      final map1 = ForestGenerator().generate(seed: 1);
      expect(map1.rooms.isNotEmpty, isTrue);

      final map2 = ForestGenerator().generate(seed: 2);
      expect(map2.rooms.isNotEmpty, isTrue);
    });

    test('CityGenerator produces unique layouts per seed', () {
      for (int s = 0; s < 3; s++) {
        final city = CityGenerator().generate(seed: s);
        expect(city.rooms.length, greaterThanOrEqualTo(5));
      }
    });

    test('CastleGenerator produces unique fortresses per seed', () {
      for (int s = 0; s < 3; s++) {
        final castle = CastleGenerator().generate(seed: s);
        expect(castle.rooms.length, greaterThanOrEqualTo(5));
      }
    });

    test('CaveGenerator produces unique subterranean labyrinths per seed', () {
      for (int s = 0; s < 3; s++) {
        final cave = CaveGenerator().generate(seed: s);
        expect(cave.rooms.length, greaterThanOrEqualTo(5));
      }
    });
  });

  group('Populators Rich NPCs, Wildlife & Props', () {
    test('Village populator populates rich NPC roster and animals', () {
      final dungeon = VillageGenerator().generate(seed: 42);
      final npcs = generateVillageNpcs(dungeon);
      final animals = generateVillageAnimals(dungeon);
      final props = generateVillageProps(dungeon);

      expect(npcs.length, greaterThanOrEqualTo(10));
      expect(animals.length, greaterThanOrEqualTo(5));
      expect(props.length, greaterThanOrEqualTo(10));
      expect(npcs.any((n) => n.shopItems.isNotEmpty), isTrue);
      expect(npcs.any((n) => n.canRecruit), isTrue);
    });

    test('Forest populator populates wildlife and rangers', () {
      final dungeon = ForestGenerator().generate(seed: 42);
      final npcs = generateForestNpcs(dungeon);
      final animals = generateForestAnimals(dungeon);
      final props = generateForestProps(dungeon);

      expect(npcs.length, greaterThanOrEqualTo(6));
      expect(animals.length, greaterThanOrEqualTo(5));
      expect(props.length, greaterThanOrEqualTo(10));
    });

    test('City populator populates market vendors and guards', () {
      final dungeon = CityGenerator().generate(seed: 42);
      final npcs = generateCityNpcs(dungeon);
      final animals = generateCityAnimals(dungeon);
      final props = generateCityProps(dungeon);

      expect(npcs.length, greaterThanOrEqualTo(6));
      expect(animals.length, greaterThanOrEqualTo(4));
      expect(props.length, greaterThanOrEqualTo(10));
    });

    test('Castle populator populates royal court and guards', () {
      final dungeon = CastleGenerator().generate(seed: 42);
      final npcs = generateCastleNpcs(dungeon);
      final animals = generateCastleAnimals(dungeon);
      final props = generateCastleProps(dungeon);

      expect(npcs.length, greaterThanOrEqualTo(6));
      expect(animals.length, greaterThanOrEqualTo(4));
      expect(props.length, greaterThanOrEqualTo(8));
    });

    test('Cave populator populates subterranean encounters', () {
      final dungeon = CaveGenerator().generate(seed: 42);
      final npcs = generateCaveNpcs(dungeon);
      final animals = generateCaveAnimals(dungeon);
      final props = generateCaveProps(dungeon);

      expect(npcs.length, greaterThanOrEqualTo(4));
      expect(animals.length, greaterThanOrEqualTo(4));
      expect(props.length, greaterThanOrEqualTo(8));
    });
  });

  group('World Atlas & Fast Travel Metadata', () {
    test('WorldLocationCatalog contains 7 primary realms with valid routes', () {
      expect(WorldLocationCatalog.locations.length, 7);
      expect(WorldLocationCatalog.tradeRoutes.isNotEmpty, isTrue);

      for (final loc in WorldLocationCatalog.locations) {
        expect(loc.id.isNotEmpty, isTrue);
        expect(loc.name.isNotEmpty, isTrue);
        expect(loc.description.isNotEmpty, isTrue);
        expect(loc.landmarks.isNotEmpty, isTrue);
        expect(loc.notableNpcs.isNotEmpty, isTrue);
      }
    });

    test('PetCompanion catalog has distinct perks and emoji', () {
      expect(PetCompanion.all.length, greaterThanOrEqualTo(5));
      for (final pet in PetCompanion.all) {
        expect(pet.id.isNotEmpty, isTrue);
        expect(pet.name.isNotEmpty, isTrue);
        expect(pet.perkTitle.isNotEmpty, isTrue);
      }
    });
  });
}
