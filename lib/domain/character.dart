import 'ability_scores.dart';

enum Race {
  human('Human', '+1 to all abilities', 'Versatile and ambitious, humans adapt to any path.'),
  elf('Elf', '+2 DEX', 'Graceful and long-lived, attuned to magic and the wilds.'),
  dwarf('Dwarf', '+2 CON', 'Stout and steadfast, masters of stone and steel.'),
  halfling('Halfling', '+2 DEX', 'Small, brave, and lucky beyond reason.'),
  orc('Orc', '+2 STR, +1 CON', 'Fierce warriors with indomitable strength.'),
  tiefling('Tiefling', '+2 CHA, +1 INT', 'Marked by infernal heritage, charismatic and cunning.'),
  dragonborn('Dragonborn', '+2 STR, +1 CHA', 'Draconic blood, breath weapon, noble presence.');

  final String label;
  final String bonus;
  final String flavor;
  const Race(this.label, this.bonus, this.flavor);
}

enum CharClass {
  fighter('Fighter', 'd10', 'Master of weapons and armor, frontline bulwark.'),
  wizard('Wizard', 'd6', 'Arcane scholar, wielder of world-bending spells.'),
  rogue('Rogue', 'd8', 'Stealth, precision, and cunning — strike from shadows.'),
  cleric('Cleric', 'd8', 'Divine conduit, healer and holy warrior.'),
  ranger('Ranger', 'd8', 'Warden of the wilds, tracker and archer.'),
  bard('Bard', 'd8', 'Charismatic performer, magic through art.'),
  barbarian('Barbarian', 'd12', 'Unbridled fury, unstoppable resilience.'),
  paladin('Paladin', 'd10', 'Oath-bound champion, radiant protector.');

  final String label;
  final String hitDie;
  final String flavor;
  const CharClass(this.label, this.hitDie, this.flavor);
}

enum Background {
  soldier('Soldier', 'Military rank, tactical insight.'),
  sage('Sage', 'Researcher, keeper of forgotten lore.'),
  criminal('Criminal', 'Underworld contacts, nimble fingers.'),
  folkHero('Folk Hero', 'Loved by common folk, rustic hospitality.'),
  acolyte('Acolyte', 'Temple service, divine insight.'),
  noble('Noble', 'Position of privilege, refined bearing.'),
  hermit('Hermit', 'Discovery, secluded revelation.'),
  outlander('Outlander', 'Wanderer, keen survivalist.');

  final String label;
  final String flavor;
  const Background(this.label, this.flavor);
}

class AvatarConfig {
  final String body;
  final String face;
  final String hair;
  final String outfit;
  final String accessory;
  final String eyeColor;
  final String aura;
  final String weapon;
  final String title;
  final String battleCry;

  const AvatarConfig({
    this.body = 'body_1',
    this.face = 'face_1',
    this.hair = 'hair_1',
    this.outfit = 'outfit_1',
    this.accessory = 'none',
    this.eyeColor = '#8B5CF6',
    this.aura = 'arcane',
    this.weapon = 'Runed Greatsword',
    this.title = 'The Undaunted',
    this.battleCry = 'For glory and the dawn!',
  });

  AvatarConfig copyWith({
    String? body,
    String? face,
    String? hair,
    String? outfit,
    String? accessory,
    String? eyeColor,
    String? aura,
    String? weapon,
    String? title,
    String? battleCry,
  }) =>
      AvatarConfig(
        body: body ?? this.body,
        face: face ?? this.face,
        hair: hair ?? this.hair,
        outfit: outfit ?? this.outfit,
        accessory: accessory ?? this.accessory,
        eyeColor: eyeColor ?? this.eyeColor,
        aura: aura ?? this.aura,
        weapon: weapon ?? this.weapon,
        title: title ?? this.title,
        battleCry: battleCry ?? this.battleCry,
      );

  Map<String, dynamic> toJson() => {
        'body': body,
        'face': face,
        'hair': hair,
        'outfit': outfit,
        'accessory': accessory,
        'eyeColor': eyeColor,
        'aura': aura,
        'weapon': weapon,
        'title': title,
        'battleCry': battleCry,
      };
  factory AvatarConfig.fromJson(Map<String, dynamic> j) => AvatarConfig(
        body: j['body'] as String? ?? 'body_1',
        face: j['face'] as String? ?? 'face_1',
        hair: j['hair'] as String? ?? 'hair_1',
        outfit: j['outfit'] as String? ?? 'outfit_1',
        accessory: j['accessory'] as String? ?? 'none',
        eyeColor: j['eyeColor'] as String? ?? '#8B5CF6',
        aura: j['aura'] as String? ?? 'arcane',
        weapon: j['weapon'] as String? ?? 'Runed Greatsword',
        title: j['title'] as String? ?? 'The Undaunted',
        battleCry: j['battleCry'] as String? ?? 'For glory and the dawn!',
      );
}

class Character {
  final String id;
  final String name;
  final Race race;
  final CharClass charClass;
  final Background background;
  final AbilityScores abilities;
  final int hp;
  final int armorClass;
  final int level;
  final List<String> inventory;
  final AvatarConfig avatar;
  // On-device TTS voice assigned to this character (see TtsService) — null
  // means "no voice picked yet", falling back to the platform's default.
  final String? voiceName;
  final String? voiceLocale;

  Character({
    required this.id,
    required this.name,
    required this.race,
    required this.charClass,
    required this.background,
    required this.abilities,
    required this.hp,
    required this.armorClass,
    this.level = 1,
    this.inventory = const [],
    this.avatar = const AvatarConfig(),
    this.voiceName,
    this.voiceLocale,
  });

  static int computeHp(CharClass c, int conMod) {
    final die = {'d6': 6, 'd8': 8, 'd10': 10, 'd12': 12}[c.hitDie] ?? 8;
    return die + conMod;
  }

  static int computeAc(int dexMod) => 10 + dexMod;

  Character copyWith({
    String? name,
    Race? race,
    CharClass? charClass,
    Background? background,
    AbilityScores? abilities,
    int? hp,
    int? armorClass,
    AvatarConfig? avatar,
    List<String>? inventory,
    String? voiceName,
    String? voiceLocale,
  }) =>
      Character(
        id: id,
        name: name ?? this.name,
        race: race ?? this.race,
        charClass: charClass ?? this.charClass,
        background: background ?? this.background,
        abilities: abilities ?? this.abilities,
        hp: hp ?? this.hp,
        armorClass: armorClass ?? this.armorClass,
        inventory: inventory ?? this.inventory,
        avatar: avatar ?? this.avatar,
        level: level,
        voiceName: voiceName ?? this.voiceName,
        voiceLocale: voiceLocale ?? this.voiceLocale,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'race': race.name,
        'charClass': charClass.name,
        'background': background.name,
        'abilities': abilities.toJson(),
        'hp': hp,
        'armorClass': armorClass,
        'level': level,
        'inventory': inventory,
        'avatar': avatar.toJson(),
        'voiceName': voiceName,
        'voiceLocale': voiceLocale,
      };

  factory Character.fromJson(Map<String, dynamic> j) => Character(
        id: j['id'] as String,
        name: j['name'] as String,
        race: Race.values.firstWhere((e) => e.name == j['race'], orElse: () => Race.human),
        charClass: CharClass.values.firstWhere((e) => e.name == j['charClass'], orElse: () => CharClass.fighter),
        background: Background.values.firstWhere((e) => e.name == j['background'], orElse: () => Background.soldier),
        abilities: AbilityScores.fromJson(j['abilities'] as Map<String, dynamic>? ?? {}),
        hp: j['hp'] as int? ?? 10,
        armorClass: j['armorClass'] as int? ?? 10,
        level: j['level'] as int? ?? 1,
        inventory: (j['inventory'] as List?)?.cast<String>() ?? [],
        avatar: j['avatar'] != null ? AvatarConfig.fromJson(j['avatar'] as Map<String, dynamic>) : const AvatarConfig(),
        voiceName: j['voiceName'] as String?,
        voiceLocale: j['voiceLocale'] as String?,
      );
}
