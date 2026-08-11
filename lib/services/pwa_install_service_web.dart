import 'dart:async';
import 'dart:js';

/// Web implementation for PWA install functionality.
class PwaInstallService {
  static StreamController<bool>? _controller;
  static bool _initialized = false;
  static dynamic _deferredPrompt;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    try {
      // Listen for the beforeinstallprompt event
      context['addEventListener']?.callMethod(
        'beforeinstallprompt',
        (event) {
          event.callMethod('preventDefault');
          _deferredPrompt = event;
          _controller?.add(true);
        },
      );
    } catch (_) {}
  }

  static bool get canInstall => _deferredPrompt != null;

  static bool get isStandalone {
    try {
      final navigator = context['navigator'] as JsObject?;
      if (navigator == null) return false;
      return navigator['standalone'] == true ||
          windowMatchMedia('(display-mode: standalone)');
    } catch (_) {
      return false;
    }
  }

  static bool windowMatchMedia(String query) {
    try {
      final result = context['window']?.callMethod('matchMedia', [query]);
      return result != null && (result['matches'] == true);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> promptInstall() async {
    if (_deferredPrompt == null) return false;

    try {
      await _deferredPrompt.callMethod('prompt');
      final result = await _deferredPrompt.callMethod('userChoice');
      _deferredPrompt = null;
      final outcome = result['outcome'];
      return outcome == 'accepted';
    } catch (_) {
      return false;
    }
  }

  static Stream<bool> get installPromptStream {
    _controller ??= StreamController<bool>.broadcast();
    return _controller!.stream;
  }

  static Future<void> dispose() async {
    await _controller?.close();
    _controller = null;
  }
}
