import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../domain/character.dart';
import '../domain/ability_scores.dart';
import '../services/auth_service.dart';

class CharacterDraft {
  String name;
  Race race;
  CharClass charClass;
  Background background;
  AbilityScores abilities;
  AvatarConfig avatar;
  String? voiceName;
  String? voiceLocale;
  CharacterDraft({
    this.name = '',
    this.race = Race.human,
    this.charClass = CharClass.fighter,
    this.background = Background.soldier,
    this.abilities = const AbilityScores(),
    this.avatar = const AvatarConfig(),
    this.voiceName,
    this.voiceLocale,
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
      voiceName: voiceName,
      voiceLocale: voiceLocale,
    );
  }
}

class CharacterDraftNotifier extends StateNotifier<CharacterDraft> {
  CharacterDraftNotifier() : super(CharacterDraft());
  void setRace(Race r) => state = CharacterDraft(name: state.name, race: r, charClass: state.charClass, background: state.background, abilities: state.abilities, avatar: state.avatar, voiceName: state.voiceName, voiceLocale: state.voiceLocale);
  void setClass(CharClass c) => state = CharacterDraft(name: state.name, race: state.race, charClass: c, background: state.background, abilities: state.abilities, avatar: state.avatar, voiceName: state.voiceName, voiceLocale: state.voiceLocale);
  void setBackground(Background b) => state = CharacterDraft(name: state.name, race: state.race, charClass: state.charClass, background: b, abilities: state.abilities, avatar: state.avatar, voiceName: state.voiceName, voiceLocale: state.voiceLocale);
  void setName(String n) => state = CharacterDraft(name: n, race: state.race, charClass: state.charClass, background: state.background, abilities: state.abilities, avatar: state.avatar, voiceName: state.voiceName, voiceLocale: state.voiceLocale);
  void setAbilities(AbilityScores a) => state = CharacterDraft(name: state.name, race: state.race, charClass: state.charClass, background: state.background, abilities: a, avatar: state.avatar, voiceName: state.voiceName, voiceLocale: state.voiceLocale);
  void setAvatar(AvatarConfig av) => state = CharacterDraft(name: state.name, race: state.race, charClass: state.charClass, background: state.background, abilities: state.abilities, avatar: av, voiceName: state.voiceName, voiceLocale: state.voiceLocale);
  void setVoice(String? name, String? locale) => state = CharacterDraft(name: state.name, race: state.race, charClass: state.charClass, background: state.background, abilities: state.abilities, avatar: state.avatar, voiceName: name, voiceLocale: locale);
  void reset() => state = CharacterDraft();
}

final characterDraftProvider = StateNotifierProvider<CharacterDraftNotifier, CharacterDraft>((ref) => CharacterDraftNotifier());

/// Characters always live locally first (offline-first — solo play must never
/// depend on a network call). When the player has signed in with a real
/// (non-anonymous) account, every add/remove also mirrors to
/// `users/{uid}/characters/{id}` in Firestore, and signing in pulls down any
/// characters saved from another device and merges them in by id.
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

  CollectionReference<Map<String, dynamic>>? _cloudCollection() {
    final user = AuthService.instance.currentUser;
    if (user == null || user.isAnonymous) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid).collection('characters');
  }

  Future<void> add(Character c) async {
    state = [...state, c];
    await _persist();
    await _cloudCollection()?.doc(c.id).set(c.toJson()).catchError((_) {});
  }

  Future<void> updateVoice(String id, String? voiceName, String? voiceLocale) async {
    state = state.map((c) => c.id == id ? c.copyWith(voiceName: voiceName ?? '', voiceLocale: voiceLocale ?? '') : c).toList();
    await _persist();
    final updated = state.firstWhere((c) => c.id == id);
    await _cloudCollection()?.doc(id).set(updated.toJson()).catchError((_) {});
  }

  Future<void> updateCharacter(Character c) async {
    state = state.map((item) => item.id == c.id ? c : item).toList();
    await _persist();
    await _cloudCollection()?.doc(c.id).set(c.toJson()).catchError((_) {});
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _persist();
    await _cloudCollection()?.doc(id).delete().catchError((_) {});
  }

  /// Call right after a real sign-in completes: pulls this account's cloud
  /// characters and merges them into the local list (local copy wins on id
  /// collision, since it's more likely to be the actively-played version).
  Future<void> syncFromCloud() async {
    final col = _cloudCollection();
    if (col == null) return;
    try {
      final snap = await col.get();
      final cloudChars = snap.docs.map((d) => Character.fromJson(d.data())).toList();
      final localIds = state.map((c) => c.id).toSet();
      final merged = [...state, ...cloudChars.where((c) => !localIds.contains(c.id))];
      state = merged;
      await _persist();
      // Push any purely-local characters up to the cloud too, so this device's
      // roster is now fully backed up under the real account.
      final cloudIds = cloudChars.map((c) => c.id).toSet();
      for (final c in state.where((c) => !cloudIds.contains(c.id))) {
        await col.doc(c.id).set(c.toJson());
      }
    } catch (_) {
      // Offline or rules-denied — local data is still intact, just try again later.
    }
  }
}

final savedCharactersProvider = StateNotifierProvider<SavedCharactersNotifier, List<Character>>((ref) => SavedCharactersNotifier());
