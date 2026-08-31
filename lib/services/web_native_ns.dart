// Native (Android/iOS) stub for web-only APIs. Exported unprefixed (top-level
// symbols) and as `web` (namespace) by web_bridge.dart — but only on native.
// None of this executes off the web because all call sites are kIsWeb-guarded.
import 'dart:async';

class JSFunction {}
class JSAny {}
class JSBoolean {
  bool get toDart => false;
}
class JSString {}

extension FunctionToJS on Function {
  JSFunction get toJS => JSFunction();
}
extension StringToJS on String {
  JSString get toJS => JSString();
}
extension JSAnyDartify on JSAny {
  Object? dartify() => null;
}
extension JSAnyToDart on JSAny {
  dynamic get toDart => this;
}

final globalContext = _GlobalContext();
class _GlobalContext {
  bool has(String name) => false;
  dynamic callMethod(String name, [List? args]) => null;
  dynamic operator [](String name) => null;
}

class Window {
  void addEventListener(String type, Object? listener) {}
  void removeEventListener(String type, Object? listener) {}
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

final Window _nativeWindow = window;
class _WebApi {
  final Window window = _nativeWindow;
}
final web = _WebApi();
