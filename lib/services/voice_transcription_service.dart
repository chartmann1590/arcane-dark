import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

enum VoiceCommandType {
  attack,
  search,
  castSpell,
  shortRest,
  tactics,
  codex,
  minimap,
  narration,
}

class VoiceCommand {
  final VoiceCommandType type;
  final String rawText;
  final String? spellName;

  const VoiceCommand({
    required this.type,
    required this.rawText,
    this.spellName,
  });
}

/// Service providing speech-to-text voice dictation and hands-free voice commands
/// for tabletop dungeon delving and TV casting.
class VoiceTranscriptionService {
  VoiceTranscriptionService._();
  static final VoiceTranscriptionService instance = VoiceTranscriptionService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _isAvailable = false;
  bool _isListening = false;
  String _lastSpokenWords = '';
  double _soundLevel = 0.0;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get lastSpokenWords => _lastSpokenWords;
  double get soundLevel => _soundLevel;

  Future<bool> initialize() async {
    if (_initialized) return _isAvailable;
    try {
      _isAvailable = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('[VoiceTranscription] Error: ${error.errorMsg} (permanent: ${error.permanent})');
          _isListening = false;
        },
        onStatus: (String status) {
          debugPrint('[VoiceTranscription] Status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[VoiceTranscription] Initialization failed: $e');
      _isAvailable = false;
      _initialized = true;
    }
    return _isAvailable;
  }

  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
  }) async {
    if (!_initialized || !_isAvailable) {
      final ok = await initialize();
      if (!ok) return false;
    }

    try {
      _lastSpokenWords = '';
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          _lastSpokenWords = result.recognizedWords;
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            _isListening = false;
          }
        },
        onSoundLevelChange: (level) {
          _soundLevel = level;
          onSoundLevel?.call(level);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceTranscription] startListening error: $e');
      _isListening = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
  }

  /// Parses transcribed words into actionable D&D voice command intents.
  static VoiceCommand parseIntent(String speechText) {
    final text = speechText.trim().toLowerCase();
    if (text.isEmpty) {
      return VoiceCommand(type: VoiceCommandType.narration, rawText: speechText);
    }

    if (text.contains('magic missile')) {
      return VoiceCommand(type: VoiceCommandType.castSpell, rawText: speechText, spellName: 'Magic Missile');
    } else if (text.contains('cure wound') || text.contains('healing') || text.contains('cure')) {
      return VoiceCommand(type: VoiceCommandType.castSpell, rawText: speechText, spellName: 'Cure Wounds');
    } else if (text.contains('sacred flame') || text.contains('divine flame')) {
      return VoiceCommand(type: VoiceCommandType.castSpell, rawText: speechText, spellName: 'Sacred Flame');
    } else if (text.startsWith('cast ') || text.contains(' cast spell') || text == 'spells' || text == 'spell') {
      return VoiceCommand(type: VoiceCommandType.castSpell, rawText: speechText);
    } else if (text == 'attack' || text.contains('strike') || text.contains('fight') || text.contains('slash') || text.contains('attack the enemy')) {
      return VoiceCommand(type: VoiceCommandType.attack, rawText: speechText);
    } else if (text == 'search' || text.contains('check for trap') || text.contains('look around') || text.contains('inspect room') || text.contains('perception check')) {
      return VoiceCommand(type: VoiceCommandType.search, rawText: speechText);
    } else if (text.contains('short rest') || text == 'rest' || text.contains('take a break') || text.contains('camp')) {
      return VoiceCommand(type: VoiceCommandType.shortRest, rawText: speechText);
    } else if (text.contains('tactic') || text.contains('companion order') || text.contains('take point') || text.contains('party defense')) {
      return VoiceCommand(type: VoiceCommandType.tactics, rawText: speechText);
    } else if (text.contains('codex') || text.contains('quest log') || text.contains('chambers') || text.contains('journal')) {
      return VoiceCommand(type: VoiceCommandType.codex, rawText: speechText);
    } else if (text == 'map' || text.contains('minimap') || text.contains('dungeon map')) {
      return VoiceCommand(type: VoiceCommandType.minimap, rawText: speechText);
    }

    return VoiceCommand(type: VoiceCommandType.narration, rawText: speechText);
  }
}
