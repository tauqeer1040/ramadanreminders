import 'package:audioplayers/audioplayers.dart' deferred as ap;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SfxService {
  static final SfxService _instance = SfxService._internal();
  factory SfxService() => _instance;
  SfxService._internal();

  dynamic _positivePlayer;
  dynamic _negativePlayer;
  bool _libsLoaded = false;
  bool _initialized = false;
  bool _sfxEnabled = true;

  static const String _prefKeyEnabled = 'sfx_enabled';

  bool get isSfxEnabled => _sfxEnabled;

  Future<void> _ensureLibs() async {
    if (!_libsLoaded) {
      await ap.loadLibrary();
      _positivePlayer = ap.AudioPlayer();
      _negativePlayer = ap.AudioPlayer();
      _libsLoaded = true;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    await _ensureLibs();

    final prefs = await SharedPreferences.getInstance();
    _sfxEnabled = prefs.getBool(_prefKeyEnabled) ?? true;

    _positivePlayer!.setVolume(0.5);
    _negativePlayer!.setVolume(0.5);
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
    await _ensureLibs();
    try {
      await _positivePlayer?.stop();
      await _positivePlayer?.play(ap.AssetSource('tunes/positive_tone_a6b6.wav'));
    } catch (e) {
      debugPrint("Error playing positive sfx: $e");
    }
  }

  Future<void> playNegative() async {
    if (!_sfxEnabled) return;
    await _ensureLibs();
    try {
      await _negativePlayer?.stop();
      await _negativePlayer?.play(ap.AssetSource('tunes/negative_tone_f5.wav'));
    } catch (e) {
      debugPrint("Error playing negative sfx: $e");
    }
  }

  void dispose() {
    _positivePlayer?.dispose();
    _negativePlayer?.dispose();
  }
}
