import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SfxService {
  static final SfxService _instance = SfxService._internal();
  factory SfxService() => _instance;
  SfxService._internal();

  final AudioPlayer _positivePlayer = AudioPlayer();
  final AudioPlayer _negativePlayer = AudioPlayer();
  bool _initialized = false;
  bool _sfxEnabled = true;

  static const String _prefKeyEnabled = 'sfx_enabled';

  bool get isSfxEnabled => _sfxEnabled;

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _sfxEnabled = prefs.getBool(_prefKeyEnabled) ?? true;

    _positivePlayer.setVolume(0.5);
    _negativePlayer.setVolume(0.5);
    _initialized = true;
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, enabled);
  }

  Future<void> toggleSfx() async {
    await setSfxEnabled(!_sfxEnabled);
  }

  Future<void> playPositive() async {
    if (!_sfxEnabled) return;
    try {
      await _positivePlayer.stop();
      await _positivePlayer.play(AssetSource('tunes/positive_tone_a6b6.wav'));
    } catch (e) {
      debugPrint("Error playing positive sfx: $e");
    }
  }

  Future<void> playNegative() async {
    if (!_sfxEnabled) return;
    try {
      await _negativePlayer.stop();
      await _negativePlayer.play(AssetSource('tunes/negative_tone_f5.wav'));
    } catch (e) {
      debugPrint("Error playing negative sfx: $e");
    }
  }

  void dispose() {
    _positivePlayer.dispose();
    _negativePlayer.dispose();
  }
}
