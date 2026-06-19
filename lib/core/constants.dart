class AppConstants {
  // Examples:
  // flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.100:3007/api/v2
  // flutter run --dart-define=BACKEND_HOST=192.168.1.100
  //
  // Notes:
  // - Android emulator: run `adb reverse tcp:3007 tcp:3007` for localhost to work.
  // - iOS simulator: localhost works by default.
  // - Physical device: use your computer's LAN IP as BACKEND_HOST.
  static const String _backendBaseUrlDefine = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  static const String _backendHostDefine = String.fromEnvironment(
    'BACKEND_HOST',
    defaultValue: '',
  );

  static String get backendUrl {
    if (_backendBaseUrlDefine.isNotEmpty) {
      return _backendBaseUrlDefine;
    }

    final host = _backendHostDefine.isNotEmpty
        ? _backendHostDefine
        : _defaultBackendHost();
    return 'http://$host:3007/api/v2';
  }

  static String _defaultBackendHost() {
    return 'localhost';
  }
}
