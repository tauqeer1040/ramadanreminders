import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenshot_detect/flutter_screenshot_detect.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a rendered insight image to stories.
///
/// Android goes through a platform channel: Instagram's ADD_TO_STORY intent
/// and a package-targeted WhatsApp send (whose picker includes My Status).
/// Anything else (iOS, missing apps) falls back to the system share sheet.
class StoryShareService {
  static const MethodChannel _channel = MethodChannel(
    'com.taucity.meowmin/share',
  );

  static Future<bool> shareInstagramStory(String imagePath) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareInstagramStory', {
        'imagePath': imagePath,
      });
      debugPrint('[StoryShare] instagram story ok=$ok');
      return ok ?? false;
    } catch (e) {
      debugPrint('[StoryShare] instagram story FAILED: $e');
      return false;
    }
  }

  static Future<bool> shareWhatsappStatus(String imagePath) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareWhatsappStatus', {
        'imagePath': imagePath,
      });
      debugPrint('[StoryShare] whatsapp status ok=$ok');
      return ok ?? false;
    } catch (e) {
      debugPrint('[StoryShare] whatsapp status FAILED: $e');
      return false;
    }
  }

  static Future<void> shareSystem(String imagePath, {String? text}) async {
    await Share.shareXFiles([XFile(imagePath)], text: text);
  }

  /// OS screenshot detection via flutter_screenshot_detect (EventChannel).
  /// No extra permissions on our side: Android 14+ uses the platform
  /// screen-capture callback, iOS posts its system notification. Callers
  /// must keep a non-screenshot trigger (e.g. like) for older Android
  /// where detection is unavailable.
  static final FlutterScreenshotDetect _detector = FlutterScreenshotDetect();
  static StreamSubscription<FlutterScreenshotEvent>? _shotSub;

  static void listenForScreenshots(VoidCallback onScreenshot) {
    try {
      _shotSub?.cancel();
      _shotSub = _detector.onScreenshot.listen((_) {
        try {
          onScreenshot();
        } catch (_) {}
      });
    } catch (_) {}
  }

  static void stopListeningForScreenshots() {
    try {
      _shotSub?.cancel();
      _shotSub = null;
      _detector.dispose();
    } catch (_) {}
  }
}
