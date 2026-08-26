import 'dart:js_interop';

import 'package:audioplayers/audioplayers.dart' deferred as ap;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'analytics_protocol.dart';
import 'analytics_service.dart';

class BackgroundMusicService with WidgetsBindingObserver {
  static final BackgroundMusicService _instance =
      BackgroundMusicService._internal();
  factory BackgroundMusicService() => _instance;
  BackgroundMusicService._internal();

  AnalyticsProtocol _analytics = AnalyticsService.instance;

  static void injectAnalytics(AnalyticsProtocol a) {
    _instance._analytics = a;
  }

  static const MethodChannel _channel = MethodChannel('com.taucity.meowmin/widget');

  dynamic _player;
  bool _libsLoaded = false;
  bool _isInitialized = false;
  bool _musicEnabled = true;
  String? _currentTrackPath;

  // On web, browsers (especially iOS Safari) block autoplay without a user
  // gesture, so the first background-music play is deferred until the first
  // interaction. Reused JS listener so add/removeEventListener match.
  JSFunction? _webGestureListener;

  Future<bool> _isDevicePlayingAudio() async {
    try {
      final bool? isPlaying = await _channel.invokeMethod<bool>('isDevicePlayingAudio');
      return isPlaying ?? false;
    } catch (e) {
      debugPrint("Error checking device audio status: $e");
      return false;
    }
  }

  static const String _prefKeyEnabled = 'background_music_enabled';
  static const String _prefKeyTrack = 'background_music_track';
  static const String _defaultTrack = 'tunes/app_audio_5min.m4a';

  bool get isMusicEnabled => _musicEnabled;
  String? get currentTrackPath => _currentTrackPath;

  Future<void> init() async {
    if (_isInitialized) return;
    if (!_libsLoaded) {
      await ap.loadLibrary();
      _player = ap.AudioPlayer();
      _libsLoaded = true;
    }

    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool(_prefKeyEnabled) ?? true;
    _currentTrackPath = prefs.getString(_prefKeyTrack);

    _player!.setPlayerMode(ap.PlayerMode.mediaPlayer);
    _player!.setReleaseMode(ap.ReleaseMode.loop);
    _player!.setVolume(1.0);

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    if (_musicEnabled) {
      final track = _currentTrackPath ?? _defaultTrack;
      if (kIsWeb) {
        _deferUntilWebGesture(track);
      } else {
        await _playTrack(track);
      }
    }
  }

  void _deferUntilWebGesture(String track) {
    void handler(web.Event _) {
      if (_musicEnabled) {
        _playTrack(track);
      }
    }

    _webGestureListener = handler.toJS;
    web.window.addEventListener('pointerdown', _webGestureListener);
    web.window.addEventListener('keydown', _webGestureListener);
    web.window.addEventListener('touchstart', _webGestureListener);
  }

  void _cancelDeferredWebPlay() {
    if (_webGestureListener == null) return;
    web.window.removeEventListener('pointerdown', _webGestureListener);
    web.window.removeEventListener('keydown', _webGestureListener);
    web.window.removeEventListener('touchstart', _webGestureListener);
    _webGestureListener = null;
  }

  Future<void> _playTrack(String assetPath) async {
    _cancelDeferredWebPlay();
    final devicePlaying = await _isDevicePlayingAudio();
    if (devicePlaying) {
      debugPrint("Device is already playing audio. Skipping background music.");
      await _player?.stop();
      return;
    }
    try {
      await _player?.stop();
      await _player?.play(ap.AssetSource(assetPath));
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
    _analytics.logEvent('audio_track_played', params: {'track_name': assetPath.split('/').last});
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
      await _player?.stop();
    }
  }

  Future<void> toggleMusic() async {
    await setMusicEnabled(!_musicEnabled);
  }

  Future<void> stop() async {
    await _player?.stop();
  }

  Future<void> pause() async {
    await _player?.pause();
  }

  Future<void> resume() async {
    if (!_musicEnabled) return;
    final devicePlaying = await _isDevicePlayingAudio();
    if (devicePlaying) {
      debugPrint("Device is already playing audio. Pausing background music.");
      await _player?.pause();
      return;
    }
    final state = _player?.state;
    if (state == ap.PlayerState.playing) return;
    if (state == ap.PlayerState.paused) {
      await _player?.resume();
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
    _player?.dispose();
  }
}
