// Real web bindings (web-only). Exported by web_bridge.dart when running on web.
//
// Uses dart:js_util + dart:js_interop — no package:web — to avoid type clashes
// with Flutter's Animation, Navigator, Window.
export 'dart:js_interop';
export 'dart:js_interop_unsafe';

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:js_util' as jsu;

// ── Event / ErrorEvent / PromiseRejectionEvent ────────────────────────────
class Event {}

class ErrorEvent extends Event {
  String message = '';
  String filename = '';
  int lineno = 0;
  int colno = 0;
}

class PromiseRejectionEvent extends Event {
  dynamic reason;
}

// ── Notification (web API wrapper) ────────────────────────────────────────
class Notification {
  static Future<dynamic> requestPermission() async {
    try {
      final notif = jsu.getProperty(jsu.globalThis, 'Notification');
      if (notif != null) {
        final fn = jsu.getProperty(notif, 'requestPermission');
        if (fn != null) {
          return jsu.callMethod(notif, 'requestPermission', []);
        }
      }
    } catch (_) {}
    return null;
  }

  static String get permission {
    try {
      final notif = jsu.getProperty(jsu.globalThis, 'Notification');
      if (notif != null) {
        final p = jsu.getProperty(notif, 'permission');
        if (p != null) return p.toString();
      }
    } catch (_) {}
    return 'denied';
  }
}

// ── Window wrapper ────────────────────────────────────────────────────────
class Window {
  final Map<String, dynamic> _listeners = {};

  void addEventListener(String type, Function? callback, [bool? useCapture]) {
    if (callback == null) return;
    try {
      _listeners[type] = callback;
      final win = jsu.getProperty(jsu.globalThis, 'window');
      if (win != null) {
        // Wrap the callback so any JS event is accepted (PointerEvent,
        // KeyboardEvent, etc.) — the Dart type system can't enforce DOM
        // event subtypes through js_util.allowInterop.
        final jsCallback = jsu.allowInterop((dynamic _) => callback());
        jsu.callMethod(win, 'addEventListener', [type, jsCallback]);
      }
    } catch (_) {}
  }

  void removeEventListener(String type, Function? callback, [bool? useCapture]) {
    try {
      final cb = _listeners.remove(type);
      if (cb == null) return;
      final win = jsu.getProperty(jsu.globalThis, 'window');
      if (win != null) {
        final jsCallback = jsu.allowInterop((dynamic _) => cb());
        jsu.callMethod(win, 'removeEventListener', [type, jsCallback]);
      }
    } catch (_) {}
  }
}

final Window _realWindow = Window();

// ── Namespace object (mirrors web_native_ns) ──────────────────────────────
final web = _WebApiWeb();

class _WebApiWeb {
  final Window window = _realWindow;
}

// ── globalContext ──────────────────────────────────────────────────────────
final GlobalContext globalContext = GlobalContext();

class GlobalContext {
  dynamic operator [](String name) {
    try {
      return jsu.getProperty(jsu.globalThis, name);
    } catch (_) {
      return null;
    }
  }

  void callMethod(String name, [List<dynamic>? args]) {
    try {
      final fn = jsu.getProperty(jsu.globalThis, name);
      if (fn != null) {
        jsu.callMethod(jsu.globalThis, name, args ?? []);
      }
    } catch (_) {}
  }

  bool has(String name) {
    try {
      return jsu.hasProperty(jsu.globalThis, name);
    } catch (_) {
      return false;
    }
  }
}
