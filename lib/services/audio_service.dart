import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundMusicService with WidgetsBindingObserver {
  static final BackgroundMusicService _instance =
      BackgroundMusicService._internal();
  factory BackgroundMusicService() => _instance;
  BackgroundMusicService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  bool _musicEnabled = true;
  String? _currentTrackPath;

  static const String _prefKeyEnabled = 'background_music_enabled';
  static const String _prefKeyTrack = 'background_music_track';
  static const String _defaultTrack = 'tunes/app_audio_5min.m4a';

  bool get isMusicEnabled => _musicEnabled;
  String? get currentTrackPath => _currentTrackPath;

  Future<void> init() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool(_prefKeyEnabled) ?? true;
    _currentTrackPath = prefs.getString(_prefKeyTrack);

    _player.setPlayerMode(PlayerMode.mediaPlayer);
    _player.setReleaseMode(ReleaseMode.loop);
    _player.setVolume(1.0);

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    if (_musicEnabled) {
      final track = _currentTrackPath ?? _defaultTrack;
      await _playTrack(track);
    }
  }

  Future<void> _playTrack(String assetPath) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Error playing background music: $e");
    }
  }

  Future<void> play([String? assetPath]) async {
    if (assetPath == null) return;
    if (!_isInitialized) await init();
    _currentTrackPath = assetPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyTrack, assetPath);
    if (!_musicEnabled) {
      _musicEnabled = true;
      await prefs.setBool(_prefKeyEnabled, true);
    }
    await _playTrack(assetPath);
  }

  Future<void> setMusicEnabled(bool enabled) async {
    if (!_isInitialized) await init();
    _musicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, enabled);
    if (enabled) {
      if (_currentTrackPath != null) {
        await _playTrack(_currentTrackPath!);
      }
    } else {
      await _player.stop();
    }
  }

  Future<void> toggleMusic() async {
    await setMusicEnabled(!_musicEnabled);
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    if (!_musicEnabled) return;
    final state = _player.state;
    if (state == PlayerState.playing) return;
    if (state == PlayerState.paused) {
      await _player.resume();
    } else if (_currentTrackPath != null) {
      await _playTrack(_currentTrackPath!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      pause();
    } else if (state == AppLifecycleState.resumed) {
      resume();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
  }
}
