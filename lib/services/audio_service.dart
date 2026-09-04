import 'package:audioplayers/audioplayers.dart';

enum MusicTrack { tavern, dungeon }

/// Background music (looping, one at a time) + short one-shot sound effects.
/// Respects the user's Settings toggles — call [setMusicEnabled]/[setSfxEnabled]
/// whenever those change so playback reacts immediately, not just on next launch.
/// See assets/audio/LICENSES.md for where every track/SFX came from (all CC0).
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _music = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  final AudioPlayer _sfx = AudioPlayer();

  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  MusicTrack? _currentTrack;

  Future<void> init({required bool musicEnabled, required bool sfxEnabled}) async {
    _musicEnabled = musicEnabled;
    _sfxEnabled = sfxEnabled;
    await _music.setVolume(0.35);
    await _sfx.setVolume(0.7);
  }

  Future<void> setMusicEnabled(bool v) async {
    _musicEnabled = v;
    if (!v) {
      await _music.stop();
    } else if (_currentTrack != null) {
      await _playTrack(_currentTrack!);
    }
  }

  void setSfxEnabled(bool v) => _sfxEnabled = v;

  Future<void> playMusic(MusicTrack track) async {
    if (_currentTrack == track) return;
    _currentTrack = track;
    if (!_musicEnabled) return;
    await _playTrack(track);
  }

  Future<void> _playTrack(MusicTrack track) async {
    final path = switch (track) {
      MusicTrack.tavern => 'audio/ambient_tavern.ogg',
      MusicTrack.dungeon => 'audio/ambient_dungeon.ogg',
    };
    try {
      await _music.stop();
      if (_musicEnabled) {
        await _music.play(AssetSource(path));
      }
    } catch (_) {
      // Safely ignore transitional Android MediaPlayer errors (-38)
    }
  }

  Future<void> stopMusic() async {
    _currentTrack = null;
    try {
      await _music.stop();
    } catch (_) {}
  }

  Future<void> playTap() => _playSfx('audio/ui_tap.ogg');
  Future<void> playSuccess() => _playSfx('audio/ui_success.ogg');
  Future<void> playError() => _playSfx('audio/ui_error.ogg');
  Future<void> playSend() => _playSfx('audio/ui_send.ogg');
  Future<void> playDiceRoll() => _playSfx('audio/dice_roll.flac');

  Future<void> _playSfx(String assetPath) async {
    if (!_sfxEnabled) return;
    try {
      await _sfx.play(AssetSource(assetPath));
    } catch (_) {
      // Never let a sound effect failure interrupt gameplay.
    }
  }
}
