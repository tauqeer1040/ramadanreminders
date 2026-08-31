// Stub for web-only APIs so the app compiles on native (Android/iOS) platforms.
// Every web-specific call site in the app is guarded by kIsWeb at runtime, so
// none of this code is ever executed off the web — it only needs to type-check.
import 'dart:async';

class JSFunction {}
class JSAny {}
class JSBoolean {
  bool get toDart => false;
}
class JSString {}

extension _FunctionToJS on Function {
  JSFunction get toJS => JSFunction();
}
extension _StringToJS on String {
  JSString get toJS => JSString();
}
extension _JSAnyDartify on JSAny {
  Object? dartify() => null;
}
extension _JSAnyToDart on JSAny {
  dynamic get toDart => this;
}

final globalContext = _GlobalContext();
class _GlobalContext {
  bool has(String name) => false;
  dynamic callMethod(String name, [List? args]) => null;
  dynamic operator [](String name) => null;
}

class Window {
  void addEventListener(String type, JSFunction? listener) {}
  void removeEventListener(String type, JSFunction? listener) {}
}
final window = Window();

class Event {}
class ErrorEvent {
  String message = '';
  String filename = '';
  int lineno = 0;
  int colno = 0;
}
class PromiseRejectionEvent {
  JSAny? reason;
}
class Notification {
  static JSPromiseStub requestPermission() => JSPromiseStub();
  static String get permission => 'denied';
}
class JSPromiseStub {
  Future<dynamic> get toDart => Future.value(null);
}
