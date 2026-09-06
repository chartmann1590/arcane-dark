class CampaignSeed {
  final String id;
  final String title;
  final String setting;
  final String tone;
  final String hook;
  final List<String> beats;
  final String startingLocation;
  final String villain;

  const CampaignSeed({
    required this.id,
    required this.title,
    required this.setting,
    required this.tone,
    required this.hook,
    required this.beats,
    required this.startingLocation,
    required this.villain,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'setting': setting,
        'tone': tone,
        'hook': hook,
        'beats': beats,
        'startingLocation': startingLocation,
        'villain': villain,
      };

  factory CampaignSeed.fromJson(Map<String, dynamic> j) => CampaignSeed(
        id: j['id'] as String,
        title: j['title'] as String,
        setting: j['setting'] as String,
        tone: j['tone'] as String,
        hook: j['hook'] as String,
        beats: (j['beats'] as List).cast<String>(),
        startingLocation: j['startingLocation'] as String,
        villain: j['villain'] as String,
      );

  static const tones = ['Classic Fantasy', 'Grimdark', 'High-Magic Wonder', 'Horror'];
  static final presets = <CampaignSeed>[
    CampaignSeed(
      id: 'whispering_crypts',
      title: 'The Whispering Crypts',
      setting: 'Ancient city of Oakhaven',
      tone: 'Classic Fantasy',
      hook: 'Deep beneath Oakhaven, restless spirits have begun to stir once more...',
      beats: [
        'Investigate the crypt\'s sealed entrance',
        'Uncover the betrayal of the Hollow King',
        'Gather the three Sigils of Binding',
        'Confront the Whispering One in the deep sanctum',
        'Choose: seal the crypt or claim its power',
      ],
      startingLocation: 'Oakhaven Tavern — The Gilded Griffin',
      villain: 'The Hollow King',
    ),
    CampaignSeed(
      id: 'ember_wastes',
      title: 'Ember of the Wastes',
      setting: 'Ashen frontier beyond the wall',
      tone: 'Grimdark',
      hook: 'The wastes whisper of a dying ember that could rekindle the world — or end it.',
      beats: [
        'Survive the crossing of the Ashen Expanse',
        'Broker peace between Dust Clans',
        'Delve the Obsidian Forge',
        'Face the Ember Guardian',
      ],
      startingLocation: 'Wall Outpost K-9',
      villain: 'Ashen Matriarch',
    ),
    CampaignSeed(
      id: 'frostpeak_spire',
      title: 'The Frostpeak Spire',
      setting: 'Glacial peaks of the Wyrmtooth Range',
      tone: 'High-Magic Wonder',
      hook: 'An eternal blizzard shrouds the celestial observatory atop the Spire, freezing time and waking crystalline horrors.',
      beats: [
        'Ascend the treacherous Avalan Pass',
        'Solve the Prismatic Mirror Gate',
        'Repel the Frost Revenant ambush',
        'Confront Archmage Vhol in the Observatory of Eternity',
        'Choose: shatter the chronal core or harness timeless power',
      ],
      startingLocation: 'The Hearth & Wyvern Inn — Glacial Ridge',
      villain: 'Archmage Vhol, The Frostbound Sovereign',
    ),
    CampaignSeed(
      id: 'sunken_citadel',
      title: 'The Sunken Citadel',
      setting: 'Submerged obsidian ruins of the Coral Trench',
      tone: 'Horror',
      hook: 'Black tides wash ashore abyssal idols, calling leviathans from the drowned depths to drag the world under.',
      beats: [
        'Navigate the flooded grottoes of Driftwood Anchorage',
        'Recover the Pearl of Abyssal Sight',
        'Disrupt the Blood Coral summoning ritual',
        'Vanquish Priestess Xyrena in the Sunken Sanctum',
        'Choose: banish the leviathan back to the abyss or bind its cosmic tide',
      ],
      startingLocation: 'The Salty Cutlass Tavern — Driftwood Anchorage',
      villain: 'Leviathan Priestess Xyrena',
    ),
    CampaignSeed(
      id: 'clockwork_vault',
      title: 'Whispers of the Clockwork Vault',
      setting: 'Subterranean brass labyrinth of Cogsgate',
      tone: 'High-Magic Wonder',
      hook: 'Deep below Cogsgate, ancient brass automatons have resumed ticking, guarding the great Chrono-Core against arcane looters.',
      beats: [
        'Bypass the Steam Piston Gatehouse',
        'Decipher the Gearwork Runic Cipher',
        'Disable the Clockwork Automaton Sentinels',
        'Confront Overclocked Arch-Mechanist Zael',
        'Choose: stabilize the Chrono-Core or harness infinite temporal power',
      ],
      startingLocation: 'The Brass Gear Tavern — Lower Cogsgate',
      villain: 'Arch-Mechanist Zael, The Iron Sovereign',
    ),
    CampaignSeed(
      id: 'shadow_rift',
      title: 'Descent into the Shadow Rift',
      setting: 'The Underdark chasms of Umbral Spire',
      tone: 'Grimdark',
      hook: 'A fathomless fissure has split the earth, pouring shadowy horrors into the surface realms.',
      beats: [
        'Descend the Abyssal Rope Bridges of the Rift',
        'Survive the Umbral Drider Stalker Ambush',
        'Awaken the Obsidian Obelisk of Binding',
        'Slay Malakor the Shadowbound Lich in the Void Sanctum',
        'Choose: extinguish the rift flames or absorb the umbral crown',
      ],
      startingLocation: 'The Dripping Stalactite Outpost — Underdark Frontier',
      villain: 'Malakor, The Shadowbound Lich',
    ),
    CampaignSeed(
      id: 'celestial_forge',
      title: 'The Celestial Forge of Aethelgard',
      setting: 'Shattered Astral Isles drifting among falling stars',
      tone: 'High-Magic Wonder',
      hook: 'The mythic forge that crafted the gods\' blades floats in the astral sky, threatened by rogue angelic zealots.',
      beats: [
        'Cross the Starbridge of Aethelgard',
        'Gather the Three Starlight Cores',
        'Repel the Zealot Empyrean Vanguard',
        'Confront the Fallen Seraph Ignis at the Anvil of Dawn',
        'Choose: reforge the Blade of the Cosmos or seal the heavens forever',
      ],
      startingLocation: 'The Starlight Sanctuary — Drifting Observatory',
      villain: 'Ignis, The Fallen Seraph',
    ),
    CampaignSeed(
      id: 'blood_moon_manor',
      title: 'Curse of Blood Moon Manor',
      setting: 'The misty moors and gothic spires of Ravenhurst',
      tone: 'Horror',
      hook: 'Every blood moon, bells toll from the abandoned Ravenhurst Manor, and villagers vanish without a trace.',
      beats: [
        'Cross the weeping willow moors of Ravenhurst',
        'Breach the rusted gates and haunted grand ballroom',
        'Cleanse the crimson ritual mirrors in the catacombs',
        'Confront Lord Vladislaus in the Sanguine Belfry',
        'Choose: lift the bloodline curse or claim the vampire lord\'s mantle',
      ],
      startingLocation: 'The Crying Crow Tavern — Ravenhurst Village',
      villain: 'Lord Vladislaus Von Ravenhurst',
    ),
  ];
}
