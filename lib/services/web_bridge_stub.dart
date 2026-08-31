// Non-web (Android/iOS) stub. Re-exports the stub library both unprefixed (so
// top-level symbols like JSFunction/globalContext resolve) and as `web` (so
// `web.window`, `web.Event`, `web.Notification` resolve). None of this ever
// executes off the web because every call site is guarded by kIsWeb.
export 'web_stub_lib.dart';
export 'web_stub_lib.dart' as web;
