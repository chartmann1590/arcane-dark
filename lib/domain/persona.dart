import 'character.dart';

/// Deterministic, offline persona generation — every character gets a distinct
/// personality the moment they're created, with no model call and no network
/// required (works before the AI model is even downloaded). Traits are seeded
/// from the character's own id, so two Human Fighters never sound the same,
/// and the same character always regenerates the same persona from its id.
class Persona {
  final String voice; // how they speak
  final String quirk; // a distinguishing habit/trait
  final String drive; // what they want
  final String flaw; // what holds them back

  const Persona({required this.voice, required this.quirk, required this.drive, required this.flaw});

  /// One paragraph fed straight into the DM system prompt.
  String describe(String name) =>
      '$name speaks $voice. $name $quirk. Above all, $name wants $drive — but $name $flaw.';

  static const _voices = [
    'in short, clipped sentences, rarely wasting a word',
    'with florid, theatrical flourish, like every sentence is a performance',
    'quietly and carefully, weighing each word before it leaves them',
    'bluntly and without tact, saying exactly what they think',
    'with dry, deadpan humor even in danger',
    'formally and precisely, like someone reciting from memory',
    'warmly and encouragingly, always checking on their companions',
    'with a nervous energy, filling silences with chatter',
    'gruffly, softening only around those they trust',
    'in a low, measured tone that rarely rises even under pressure',
  ];
  static const _quirks = [
    'hums an old tune when concentrating',
    'always counts exits before entering a room',
    'collects small trinkets from every place they visit',
    'talks to their weapon or gear like it can hear them',
    'refuses to walk under anything they haven\'t checked for traps',
    'names every creature they meet, friend or foe',
    'keeps a running tally of debts owed and favors given',
    'never sits with their back to a door',
    'chews on a piece of dried root when thinking',
    'sketches whatever room they\'re in, even mid-crisis',
    'apologizes to inanimate objects they bump into',
    'insists on tasting unfamiliar food before anyone else does',
  ];
  static const _drives = [
    'to prove they belong among heroes, not just tag along',
    'to find someone from their past they lost touch with',
    'to pay off a debt they\'ve never spoken of aloud',
    'to uncover the truth about where they really came from',
    'to protect the only family they have left — this party',
    'to be remembered for something greater than their birth',
    'wealth enough to never depend on anyone again',
    'redemption for a mistake they haven\'t forgiven themselves for',
    'knowledge — any secret the world has kept from them',
    'a place they can finally call home',
  ];
  static const _flaws = [
    'trusts too easily, even when burned before',
    'can\'t resist a bet or a dare',
    'freezes up when someone they care about is threatened',
    'has a temper that outpaces their judgment',
    'hoards feelings until they burst out sideways',
    'is stubborn to a fault, even when clearly wrong',
    'flinches from open flame, for reasons never explained',
    'can\'t keep a secret, however hard they try',
    'undervalues themselves next to flashier companions',
    'is haunted by a promise they haven\'t kept',
  ];

  static Persona forCharacterId(String id) {
    final h = id.hashCode.abs();
    return Persona(
      voice: _voices[h % _voices.length],
      quirk: _quirks[(h ~/ 7) % _quirks.length],
      drive: _drives[(h ~/ 13) % _drives.length],
      flaw: _flaws[(h ~/ 29) % _flaws.length],
    );
  }
}

extension CharacterPersona on Character {
  String get personaDescription => Persona.forCharacterId(id).describe(name.isEmpty ? 'This hero' : name);
}
