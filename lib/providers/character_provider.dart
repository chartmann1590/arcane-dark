import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../domain/character.dart';
import '../domain/ability_scores.dart';

class CharacterDraft {
  String name;
  Race race;
  CharClass charClass;
  Background background;
  AbilityScores abilities;
  AvatarConfig avatar;
  CharacterDraft({
    this.name = '',
    this.race = Race.human,
    this.charClass = CharClass.fighter,
    this.background = Background.soldier,
    this.abilities = const AbilityScores(),
    this.avatar = const AvatarConfig(),
  });

  Character toCharacter() {
    final hp = Character.computeHp(charClass, abilities.conMod);
    final ac = Character.computeAc(abilities.dexMod);
    return Character(
      id: const Uuid().v4(),
      name: name.isEmpty ? 'Unnamed Hero' : name,
      race: race,
      charClass: charClass,
      background: background,
      abilities: abilities,
      hp: hp,
      armorClass: ac,
      avatar: avatar,
      inventory: const [],
    );
  }
}

class CharacterDraftNotifier extends StateNotifier<CharacterDraft> {
  CharacterDraftNotifier() : super(CharacterDraft());
  void setRace(Race r) => state = CharacterDraft(name: state.name, race: r, charClass: state.charClass, background: state.background, abilities: state.abilities, avatar: state.avatar);
  void setClass(CharClass c) => state = CharacterDraft(name: state.name, race: state.race, charClass: c, background: state.background, abilities: state.abilities, avatar: state.avatar);
  void setBackground(Background b) => state = CharacterDraft(name: state.name, race: state.race, charClass: state.charClass, background: b, abilities: state.abilities, avatar: state.avatar);
  void setName(String n) => state = CharacterDraft(name: n, race: state.race, charClass: state.charClass, background: state.background, abilities: state.abilities, avatar: state.avatar);
  void setAbilities(AbilityScores a) => state = CharacterDraft(name: state.name, race: state.race, charClass: state.charClass, background: state.background, abilities: a, avatar: state.avatar);
  void setAvatar(AvatarConfig av) => state = CharacterDraft(name: state.name, race: state.race, charClass: state.charClass, background: state.background, abilities: state.abilities, avatar: av);
  void reset() => state = CharacterDraft();
}

final characterDraftProvider = StateNotifierProvider<CharacterDraftNotifier, CharacterDraft>((ref) => CharacterDraftNotifier());

class SavedCharactersNotifier extends StateNotifier<List<Character>> {
  SavedCharactersNotifier() : super([]) {
    _load();
  }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('saved_characters');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        state = list.map((e) => Character.fromJson(e)).toList();
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    p.setString('saved_characters', jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> add(Character c) async {
    state = [...state, c];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _persist();
  }
}

final savedCharactersProvider = StateNotifierProvider<SavedCharactersNotifier, List<Character>>((ref) => SavedCharactersNotifier());
