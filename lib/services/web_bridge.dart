// Conditional bridge for web-only APIs.
// - On native (Android/iOS): use the local stub (web_native_ns.dart) so the app
//   compiles without dart:js_interop / package:web.
// - On web: use the real dart:js_interop / dart:js_interop_unsafe / package:web.
// Every web-specific call site is guarded by kIsWeb at runtime, so the stub
// code never executes off the web.
export 'web_native_ns.dart' if (dart.library.js_interop) 'web_bridge_web_real.dart';
