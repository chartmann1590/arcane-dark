import 'package:uuid/uuid.dart';
import 'ability_scores.dart';
import 'character.dart';

/// Pre-built AI companions a solo player can recruit straight into their
/// roster — no character-creation wizard needed. Once added they're a
/// perfectly ordinary saved Character (same personas, same voice picker,
/// same party slot in any campaign) — "AI-controlled" isn't a special flag,
/// it's just that nobody's been asked to type their appearance by hand.
class CompanionTemplate {
  final String name;
  final Race race;
  final CharClass charClass;
  final Background background;
  final AbilityScores abilities;
  final String tagline;
  const CompanionTemplate({required this.name, required this.race, required this.charClass, required this.background, required this.abilities, required this.tagline});

  Character toCharacter() {
    final hp = Character.computeHp(charClass, abilities.conMod);
    final ac = Character.computeAc(abilities.dexMod);
    return Character(
      id: const Uuid().v4(),
      name: name,
      race: race,
      charClass: charClass,
      background: background,
      abilities: abilities,
      hp: hp,
      armorClass: ac,
    );
  }
}

const companionTemplates = <CompanionTemplate>[
  CompanionTemplate(
    name: 'Kordan Steelhand',
    race: Race.dwarf,
    charClass: CharClass.fighter,
    background: Background.soldier,
    abilities: AbilityScores(str: 15, dex: 12, con: 14, int_: 10, wis: 10, cha: 9),
    tagline: 'A stoic shield-brother who\'s seen worse than whatever\'s ahead.',
  ),
  CompanionTemplate(
    name: 'Sirielle Duskwhisper',
    race: Race.elf,
    charClass: CharClass.wizard,
    background: Background.sage,
    abilities: AbilityScores(str: 8, dex: 14, con: 12, int_: 15, wis: 10, cha: 9),
    tagline: 'A scholar-mage who narrates every discovery like it\'s the point of the trip.',
  ),
  CompanionTemplate(
    name: 'Pike Ashford',
    race: Race.halfling,
    charClass: CharClass.rogue,
    background: Background.criminal,
    abilities: AbilityScores(str: 9, dex: 15, con: 12, int_: 10, wis: 12, cha: 14),
    tagline: 'Quick hands, quicker excuses, and an opinion about every lock.',
  ),
  CompanionTemplate(
    name: 'Thessaly Vane',
    race: Race.human,
    charClass: CharClass.cleric,
    background: Background.acolyte,
    abilities: AbilityScores(str: 12, dex: 10, con: 13, int_: 9, wis: 15, cha: 12),
    tagline: 'Keeps the party alive and keeps a running commentary on their choices.',
  ),
  CompanionTemplate(
    name: 'Grash Emberhide',
    race: Race.orc,
    charClass: CharClass.barbarian,
    background: Background.outlander,
    abilities: AbilityScores(str: 16, dex: 12, con: 15, int_: 8, wis: 10, cha: 9),
    tagline: 'Loud, loyal, and first through every door whether that\'s wise or not.',
  ),
  CompanionTemplate(
    name: 'Ilyra Nightsong',
    race: Race.tiefling,
    charClass: CharClass.bard,
    background: Background.noble,
    abilities: AbilityScores(str: 9, dex: 13, con: 11, int_: 10, wis: 10, cha: 15),
    tagline: 'Talks their way into rooms and out of trouble in equal measure.',
  ),
  CompanionTemplate(
    name: 'Valgar Bloodscale',
    race: Race.dragonborn,
    charClass: CharClass.paladin,
    background: Background.noble,
    abilities: AbilityScores(str: 16, dex: 10, con: 14, int_: 10, wis: 12, cha: 15),
    tagline: 'A golden-scaled knight sworn to sacred oaths, devastating foes with radiant smites.',
  ),
  CompanionTemplate(
    name: 'Lyra Windrunner',
    race: Race.elf,
    charClass: CharClass.ranger,
    background: Background.outlander,
    abilities: AbilityScores(str: 10, dex: 16, con: 13, int_: 12, wis: 15, cha: 9),
    tagline: 'A highland huntress whose unerring arrows find vulnerable points through any armor.',
  ),
  CompanionTemplate(
    name: 'Thurnic Deepdelver',
    race: Race.dwarf,
    charClass: CharClass.cleric,
    background: Background.hermit,
    abilities: AbilityScores(str: 14, dex: 10, con: 15, int_: 11, wis: 16, cha: 8),
    tagline: 'An artisan-priest who blesses party defenses and channels molten divine fury.',
  ),
  CompanionTemplate(
    name: 'Zephyr Swiftblade',
    race: Race.tiefling,
    charClass: CharClass.rogue,
    background: Background.criminal,
    abilities: AbilityScores(str: 8, dex: 16, con: 12, int_: 13, wis: 10, cha: 15),
    tagline: 'A quick-witted rogue slipping through shadows with dual poison-coated blades.',
  ),
];
