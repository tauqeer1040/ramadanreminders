// Real web bindings (web-only). Exported by web_bridge.dart when running on web.
export 'dart:js_interop';
export 'dart:js_interop_unsafe';
export 'package:web/web.dart';

// Top-level `web` object so `web.window` resolves on web (mirrors web_native_ns).
final Window _realWindow = window;
final web = _WebApiWeb();
class _WebApiWeb {
  final Window window = _realWindow;
}
