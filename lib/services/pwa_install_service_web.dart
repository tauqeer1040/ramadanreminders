import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web implementation that captures the browser's `beforeinstallprompt` event
/// so the app can offer an installable PWA shortcut ("Add to Home Screen").
class PwaInstallService {
  static JSAny? _deferredPrompt;
  static JSFunction? _installListener;
  static JSFunction? _appInstalledListener;

  /// Attach the global listeners. Safe to call more than once.
  static void init() {
    if (_installListener != null) return;

    _installListener = _capturePrompt.toJS;
    globalContext.callMethod(
      'addEventListener'.toJS,
      'beforeinstallprompt'.toJS,
      _installListener,
    );

    _appInstalledListener = ((JSAny _) => _deferredPrompt = null).toJS;
    globalContext.callMethod(
      'addEventListener'.toJS,
      'appinstalled'.toJS,
      _appInstalledListener,
    );
  }

  static void _capturePrompt(JSAny event) {
    (event as JSObject).callMethod('preventDefault'.toJS);
    _deferredPrompt = event;
  }

  /// Whether a deferred install prompt is available right now.
  static bool get canInstall => _deferredPrompt != null;

  /// Whether the app is already running as an installed PWA.
  static bool get isStandalone {
    final media =
        globalContext.callMethod<JSObject>('matchMedia'.toJS,
            '(display-mode: standalone)'.toJS);
    final matches = media.getProperty<JSBoolean>('matches'.toJS);
    return matches.toDart;
  }

  /// Ask the browser to show the install prompt. Returns false when no
  /// deferred prompt is available (e.g. already installed or iOS Safari).
  static Future<bool> promptInstall() async {
    if (_deferredPrompt == null) return false;
    final prompt = _deferredPrompt! as JSObject;
    try {
      prompt.callMethod('prompt'.toJS);
      return true;
    } catch (_) {
      return false;
    } finally {
      _deferredPrompt = null;
    }
  }
}
