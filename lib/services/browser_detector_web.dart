import 'dart:js';

/// Web implementation that reads `navigator.userAgent` to detect the browser.
class BrowserDetector {
  static BrowserInfo? _cached;

  static BrowserInfo get info {
    if (_cached != null) return _cached!;
    _cached = _detect();
    return _cached!;
  }

  static BrowserInfo _detect() {
    try {
      final navigator = context['navigator'] as JsObject?;
      final ua = navigator != null ? (navigator['userAgent']?.toString() ?? '') : '';
      return BrowserInfo._(_classify(ua), ua);
    } catch (_) {
      return BrowserInfo.unknown;
    }
  }

  static BrowserType _classify(String ua) {
    final lower = ua.toLowerCase();
    if (lower.contains('samsungbrowser')) return BrowserType.samsung;
    if (lower.contains('edg/')) return BrowserType.edge;
    if (lower.contains('firefox')) return BrowserType.firefox;
    if (lower.contains('safari') && !lower.contains('chrome') && !lower.contains('crios') && !lower.contains('fxios')) {
      return BrowserType.safari;
    }
    if (lower.contains('chrome') || lower.contains('crios')) return BrowserType.chrome;
    return BrowserType.unknown;
  }
}

enum BrowserType { chrome, safari, firefox, edge, samsung, unknown }

class BrowserInfo {
  final BrowserType type;
  final String rawUserAgent;

  const BrowserInfo._(this.type, this.rawUserAgent);

  static const unknown = BrowserInfo._(BrowserType.unknown, '');

  bool get isIOS {
    final ua = rawUserAgent.toLowerCase();
    return ua.contains('ipad') || ua.contains('iphone');
  }

  bool get isIOSafari => type == BrowserType.safari && isIOS;
  bool get isAndroidChrome => type == BrowserType.chrome && rawUserAgent.toLowerCase().contains('android');
  bool get isFirefox => type == BrowserType.firefox;
  bool get isEdge => type == BrowserType.edge;
  bool get isSamsung => type == BrowserType.samsung;

  bool get isMobile {
    final ua = rawUserAgent.toLowerCase();
    return ua.contains('android') || ua.contains('iphone') || ua.contains('ipad');
  }
}
