import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_smart_reply/google_mlkit_smart_reply.dart';
import '../domain/campaign_state.dart';
import '../domain/pet_companion.dart';

enum SuggestionType { combat, exploration, dialogue, pet, survival }

class SmartSuggestion {
  final String text;
  final String label;
  final String icon;
  final SuggestionType type;

  const SmartSuggestion({
    required this.text,
    required this.label,
    required this.icon,
    required this.type,
  });
}

/// On-Device ML Kit Smart Reply combined with tactical D&D AI heuristics.
/// Provides intelligent, context-aware action suggestions, pet commands,
/// and tactical battle advice in real-time.
class SmartAiService {
  SmartAiService._();
  static final SmartAiService instance = SmartAiService._();

  SmartReply? _smartReply;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    try {
      _smartReply = SmartReply();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[SmartAiService] ML Kit SmartReply init warning: $e');
    }
  }

  /// Generates contextual action suggestions based on recent conversation,
  /// dungeon exploration environment, party vitals, and active pet companion.
  Future<List<SmartSuggestion>> getContextualSuggestions({
    required List<Map<String, String>> chatHistory,
    CampaignState? campaign,
    PetCompanion? pet,
    bool isInCombat = false,
    String? telegraphedEnemyIntent,
    int? enemyHp,
  }) async {
    final suggestions = <SmartSuggestion>[];

    // 1. First, attempt to leverage on-device Google ML Kit Smart Reply
    if (_smartReply != null && chatHistory.isNotEmpty) {
      try {
        // Clear previous conversation buffer in ML Kit
        _smartReply!.clearConversation();

        // Feed up to 6 recent messages into ML Kit conversation model
        final recentMessages = chatHistory.length > 6
            ? chatHistory.sublist(chatHistory.length - 6)
            : chatHistory;

        final now = DateTime.now().millisecondsSinceEpoch;
        var offset = 0;

        for (final msg in recentMessages) {
          final isPlayer = msg['role'] == 'player';
          final text = msg['text'] ?? '';
          if (text.trim().isEmpty) continue;

          final timestamp = now - ((recentMessages.length - offset) * 1000);
          offset++;

          if (isPlayer) {
            _smartReply!.addMessageToConversationFromLocalUser(text, timestamp);
          } else {
            _smartReply!.addMessageToConversationFromRemoteUser(
              text,
              timestamp,
              'dungeon_master',
            );
          }
        }

        final response = await _smartReply!.suggestReplies().timeout(
          const Duration(milliseconds: 650),
          onTimeout: () => SmartReplySuggestionResult(
            status: SmartReplySuggestionResultStatus.noReply,
            suggestions: [],
          ),
        );

        if (response.status == SmartReplySuggestionResultStatus.success) {
          for (final reply in response.suggestions.take(2)) {
            if (reply.trim().isNotEmpty) {
              suggestions.add(
                SmartSuggestion(
                  text: reply,
                  label: reply,
                  icon: '💬',
                  type: SuggestionType.dialogue,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[SmartAiService] ML Kit suggestion error (fallback active): $e');
      }
    }

    // 2. Add Tactical D&D Heuristic ML Suggestions tailored to active game context
    if (isInCombat) {
      // Tactical Combat Context
      if (telegraphedEnemyIntent != null && telegraphedEnemyIntent.contains('Heavy')) {
        suggestions.insert(
          0,
          const SmartSuggestion(
            text: 'I raise my shield in full defensive guard to brace against the incoming blow!',
            label: 'Defensive Brace (Guard)',
            icon: '🛡️',
            type: SuggestionType.combat,
          ),
        );
      } else {
        suggestions.insert(
          0,
          const SmartSuggestion(
            text: 'I strike at the enemy\'s exposed weak point with full precision!',
            label: 'Flank Precision Strike',
            icon: '⚔️',
            type: SuggestionType.combat,
          ),
        );
      }

      if (pet != null && pet.id != 'none') {
        suggestions.add(
          SmartSuggestion(
            text: 'I command my ${pet.name} to execute ${pet.perkTitle}!',
            label: '${pet.emoji} ${pet.name}: ${pet.perkTitle}',
            icon: pet.emoji,
            type: SuggestionType.pet,
          ),
        );
      }

      // Party health check
      final isLowHp = campaign?.party.any((m) => m.hp <= m.maxHp * 0.4) ?? false;
      if (isLowHp) {
        suggestions.add(
          const SmartSuggestion(
            text: 'I quickly toss a potion of vital healing to my wounded ally!',
            label: 'Quick Healing Potion',
            icon: '🧪',
            type: SuggestionType.survival,
          ),
        );
      }
    } else {
      // Dungeon Exploration Context
      final lastDmMsg = chatHistory.reversed
          .where((m) => m['role'] == 'dm')
          .firstOrNull?['text']
          ?.toLowerCase() ?? '';

      if (lastDmMsg.contains('chest') || lastDmMsg.contains('lock') || lastDmMsg.contains('treasure')) {
        suggestions.insert(
          0,
          const SmartSuggestion(
            text: 'I carefully inspect the chest for hidden needle traps before attempting to open it.',
            label: 'Inspect Chest for Traps',
            icon: '🔍',
            type: SuggestionType.exploration,
          ),
        );
      } else if (lastDmMsg.contains('door') || lastDmMsg.contains('gate') || lastDmMsg.contains('passage')) {
        suggestions.insert(
          0,
          const SmartSuggestion(
            text: 'I listen closely at the door seam for breathing or movement on the other side.',
            label: 'Listen at Doorway',
            icon: '👂',
            type: SuggestionType.exploration,
          ),
        );
      } else if (lastDmMsg.contains('rune') || lastDmMsg.contains('altar') || lastDmMsg.contains('statue')) {
        suggestions.insert(
          0,
          const SmartSuggestion(
            text: 'I channel my arcane senses to decipher the ancient inscriptions and wardings.',
            label: 'Decipher Arcane Runes',
            icon: '✨',
            type: SuggestionType.exploration,
          ),
        );
      } else {
        suggestions.add(
          const SmartSuggestion(
            text: 'I search the chamber thoroughly for hidden compartments and secret doors.',
            label: 'Search for Secrets (Perception)',
            icon: '🔍',
            type: SuggestionType.exploration,
          ),
        );
      }

      // Pet exploration assist
      if (pet != null && pet.id != 'none') {
        final petActionText = switch (pet.id) {
          'tavern_hound' => 'I whistle for my Tavern Hound to sniff out danger ahead.',
          'hearth_cat' => 'My Hearth Cat prowls ahead silently, testing the stones.',
          'shadow_wolf' => 'My Shadow Wolf Pup stalks into the dark corridor, baring its teeth at shadows.',
          'spectral_owl' => 'I send my Spectral Owl aloft to scan the ceiling and high ledges for ambushes.',
          'astral_falcon' => 'My Astral Falcon screeches softly, pointing its gaze toward unseen danger.',
          'pygmy_drake' => 'My Pygmy Drake breathes a small burst of embers to illuminate dark alcoves.',
          'clockwork_spider' => 'My Clockwork Spider scuttles across the floor, feeling for mechanical tripwires.',
          'slime_blob' => 'My Gelatinous Buddy oozes forward, dissolving debris in our path.',
          _ => 'I signal my ${pet.name} to remain vigilant at my side.',
        };

        suggestions.add(
          SmartSuggestion(
            text: petActionText,
            label: '${pet.emoji} ${pet.name} Assist',
            icon: pet.emoji,
            type: SuggestionType.pet,
          ),
        );
      }

      // Tactical camp / rest suggestion if party is depleted
      final wounded = campaign?.party.any((p) => p.hp < p.maxHp) ?? false;
      if (wounded) {
        suggestions.add(
          const SmartSuggestion(
            text: 'Let us secure this area and take a short rest to bandage our wounds.',
            label: 'Take Short Rest',
            icon: '🏕️',
            type: SuggestionType.survival,
          ),
        );
      }
    }

    // Limit to top 4 diverse suggestions
    return suggestions.take(4).toList();
  }

  void dispose() {
    try {
      _smartReply?.close();
      _smartReply = null;
      _isInitialized = false;
    } catch (_) {}
  }
}
