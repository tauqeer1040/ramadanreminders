import 'package:flutter/foundation.dart';
import 'web_bridge.dart';
import 'analytics_service.dart';

/// Reports uncaught Dart errors and web JS errors to Firebase Analytics so
/// crashes on real devices (especially iOS Safari, which is hard to test on
/// directly) self-report. Rate-limited and strictly best-effort — it can
/// never take the app down.
class CrashReporter {
  static bool _initialized = false;
  static DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minInterval = Duration(seconds: 10);
  static const int _maxParamLength = 100;

  /// Installs global error handlers. Must be called once after Firebase is
  /// initialized (so Analytics is available) and before runApp().
  static void init() {
    if (_initialized) return;
    _initialized = true;

    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      _report(
        type: 'flutter_error',
        message: details.exceptionAsString(),
        detail: details.stack?.toString() ?? '',
      );
      previousFlutterError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _report(type: 'dart_async_error', message: error.toString(), detail: stack.toString());
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(FlutterErrorDetails(exception: error, stack: stack));
      }
      return true;
    };

    if (kIsWeb) {
      _initWebHandlers();
    }
  }

  /// Catches errors from the raw web platform (DOM, injected scripts, async
  /// promise rejections) that never surface as Dart errors.
  static void _initWebHandlers() {
    try {
      web.window.addEventListener('error', ((Event event) {
        try {
          final e = event as ErrorEvent;
          _report(
            type: 'web_error',
            message: e.message,
            detail: '${e.filename}:${e.lineno}:${e.colno}',
          );
        } catch (_) {}
        }));

      web.window.addEventListener('unhandledrejection', ((Event event) {
        try {
          final e = event as PromiseRejectionEvent;
          _report(
            type: 'web_unhandled_rejection',
            message: _stringifyJs(e.reason),
            detail: '',
          );
        } catch (_) {}
        }));
    } catch (_) {
      // Never let crash reporting itself break the app.
    }
  }

  static String _stringifyJs(JSAny? value) {
    if (value == null) return 'null';
    try {
      final converted = value.dartify();
      if (converted is String) return converted;
      return converted?.toString() ?? 'unknown';
    } catch (_) {
      return value.toString();
    }
  }

  static void _report({required String type, required String message, required String detail}) {
    if (!_initialized) return;
    final now = DateTime.now();
    if (now.difference(_lastReport) < _minInterval) return;
    _lastReport = now;

    if (_isNoise(message)) return;

    try {
      AnalyticsService.instance.logEvent('app_crash', params: {
        'type': type,
        'error': _clip(message),
        'stack': _clip(detail),
        'location': _clip(Uri.base.toString()),
      });
    } catch (_) {}
  }

  static bool _isNoise(String message) {
    if (message.contains('MissingPluginException')) return true;
    if (message.contains('RenderBox was not laid out')) return true;
    if (message.contains('does not have any constraints before it has been laid out')) {
      return true;
    }
    return false;
  }

  static String _clip(String value) =>
      value.length <= _maxParamLength ? value : value.substring(0, _maxParamLength);
}
