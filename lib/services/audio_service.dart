import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class BackgroundMusicService with WidgetsBindingObserver {
  static final BackgroundMusicService _instance = BackgroundMusicService._internal();
  factory BackgroundMusicService() => _instance;
  BackgroundMusicService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    _player.setReleaseMode(ReleaseMode.loop);
    _player.setVolume(0.5); // Start with moderate volume
    
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    
    await play();
  }

  Future<void> play() async {
    try {
      await _player.play(AssetSource('tunes/app_audio_5min.m4a'));
    } catch (e) {
      debugPrint("Error playing background music: $e");
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.resume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
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
