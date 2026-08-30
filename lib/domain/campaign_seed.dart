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
  ];
}
