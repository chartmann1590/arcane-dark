// Simple local persistence stub for MVP.
// Full Drift schema (campaign_states, characters, visited_tiles) will replace this
// once codegen is wired; for now we use SharedPreferences JSON and keep the API
// surface compatible so call sites don't change.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/character.dart';
import '../../domain/campaign_state.dart';
import '../../domain/campaign_seed.dart';

class AppDatabase {
  static const _charsKey = 'db_characters';
  static const _campaignsKey = 'db_campaigns';

  Future<List<Character>> getAllCharacters() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_charsKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((e) => Character.fromJson(e)).toList();
  }

  Future<void> insertCharacter(Character c) async {
    final all = await getAllCharacters();
    all.add(c);
    final p = await SharedPreferences.getInstance();
    p.setString(_charsKey, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<void> open() async {
    // Prove DB opens — logs line for Phase 01 acceptance
    // ignore: avoid_print
    print('[AppDatabase] opened (SharedPreferences backend)');
  }
}
