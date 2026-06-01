import 'package:flutter/foundation.dart';

class AuthDebugEvent {
  final DateTime timestamp;
  final String type;
  final String message;
  final Map<String, String>? details;

  AuthDebugEvent({
    required this.type,
    required this.message,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AuthDebugService extends ChangeNotifier {
  static final AuthDebugService _instance = AuthDebugService._internal();
  factory AuthDebugService() => _instance;
  AuthDebugService._internal();

  final List<AuthDebugEvent> _events = [];
  String? _lastError;
  String? _lastErrorDetails;
  bool _lastSignInSuccess = false;

  List<AuthDebugEvent> get events => List.unmodifiable(_events);
  String? get lastError => _lastError;
  String? get lastErrorDetails => _lastErrorDetails;
  bool get lastSignInSuccess => _lastSignInSuccess;

  void logSignInAttempt() {
    _events.insert(0, AuthDebugEvent(type: 'ATTEMPT', message: 'Google sign-in started'));
    if (_events.length > 50) _events.removeLast();
    _lastError = null;
    _lastErrorDetails = null;
    _lastSignInSuccess = false;
    notifyListeners();
  }

  void logSignInSuccess({Map<String, String>? details}) {
    _events.insert(0, AuthDebugEvent(
      type: 'SUCCESS',
      message: 'Google sign-in succeeded',
      details: details,
    ));
    if (_events.length > 50) _events.removeLast();
    _lastSignInSuccess = true;
    notifyListeners();
  }

  void logSignInError(Object error, {String? stackTrace}) {
    final msg = error.toString();
    _events.insert(0, AuthDebugEvent(
      type: 'ERROR',
      message: msg,
      details: stackTrace != null ? {'stack': stackTrace} : null,
    ));
    if (_events.length > 50) _events.removeLast();
    _lastError = msg;
    _lastErrorDetails = stackTrace;
    _lastSignInSuccess = false;
    notifyListeners();
  }

  void logEvent(String type, String message, {Map<String, String>? details}) {
    _events.insert(0, AuthDebugEvent(type: type, message: message, details: details));
    if (_events.length > 50) _events.removeLast();
    notifyListeners();
  }

  void logAuthStateChange(Map<String, String> details) {
    _events.insert(0, AuthDebugEvent(
      type: 'AUTH_STATE',
      message: 'Auth state changed',
      details: details,
    ));
    if (_events.length > 50) _events.removeLast();
    notifyListeners();
  }

  void clear() {
    _events.clear();
    _lastError = null;
    _lastErrorDetails = null;
    notifyListeners();
  }
}
