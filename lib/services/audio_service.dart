import 'package:audioplayers/audioplayers.dart' deferred as ap;
import 'web_bridge.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _initializing = false;
  bool _starting = false;
  bool _musicEnabled = true;
  String? _currentTrackPath;

  // On web, browsers (especially iOS Safari) block autoplay without a user
  // gesture, so the first background-music play is deferred until the first
  // interaction. Reused JS listener so add/removeEventListener match.
  void Function(Event)? _webGestureListener;

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
  static const String _defaultTrack = 'tunes/1_A.M_Study_Session_lofi_hip_hop_5min.m4a';

  bool get isMusicEnabled => _musicEnabled;
  String? get currentTrackPath => _currentTrackPath;

  // Foreground-only audio: set false the moment the app backgrounds so a
  // play() that is mid-start (async gap in _playTrack) cannot complete
  // behind the user's back. Re-checked after every await in _playTrack.
  bool _isForeground = true;

  Future<void> init() async {
    if (_isInitialized) return;
    if (_initializing) {
      while (_initializing && !_isInitialized) {
        await Future.delayed(const Duration(milliseconds: 25));
      }
      return;
    }
    _initializing = true;
    try {
      await _initInternal();
    } finally {
      _initializing = false;
    }
  }

  Future<void> _initInternal() async {
    if (_isInitialized) return;
    if (!_libsLoaded) {
      await ap.loadLibrary();
      _player = ap.AudioPlayer();
      _libsLoaded = true;
    }

    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool(_prefKeyEnabled) ?? true;
    _currentTrackPath = prefs.getString(_prefKeyTrack);
    // Migration: remove After_Dark / app_audio legacy picks → force study track
    if (_currentTrackPath != null &&
        (_currentTrackPath!.contains('Cairo') ||
            _currentTrackPath!.contains('After_Dark') ||
            _currentTrackPath!.contains('app_audio'))) {
      _currentTrackPath = _defaultTrack;
      await prefs.setString(_prefKeyTrack, _defaultTrack);
    }

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
    void handler(Event _) {
      if (_musicEnabled) {
        _playTrack(track);
      }
    }

    _webGestureListener = handler;
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
    if (_starting) return; // another start in flight — it wins.
    _starting = true;
    try {
      // isMusicActive hears EVERYTHING, including our own player. If we are
      // already playing, the "device audio" is us — proceed to switch tracks.
      final ownPlaying = _player?.state == ap.PlayerState.playing;
      if (!ownPlaying && await _isDevicePlayingAudio()) {
        debugPrint("Device is already playing audio. Skipping background music.");
        await _player?.stop();
        return;
      }
      if (!_isForeground || !_musicEnabled) {
        // App backgrounded (or music disabled) while starting — stay silent.
        await _player?.stop();
        return;
      }
      try {
        await _player?.stop();
        if (!_isForeground || !_musicEnabled) {
          return;
        }
        await _player?.play(ap.AssetSource(assetPath));
        if (!_isForeground || !_musicEnabled) {
          // Backgrounded mid-start: the pending play() won the race — silence it.
          await _player?.pause();
        }
      } catch (e) {
        debugPrint("Error playing background music: $e");
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> play([String? assetPath]) async {
    if (assetPath == null) return;
    if (!_isInitialized) await init();
    // Same track already playing (e.g. onboarding music page re-entering
    // while bootstrap autoplay is running) — don't restart it.
    if (assetPath == _currentTrackPath &&
        _player?.state == ap.PlayerState.playing) {
      return;
    }
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
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _isForeground = false;
      pause();
    } else if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      resume();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player?.dispose();
  }
}
