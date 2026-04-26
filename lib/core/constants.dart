class AppConstants {
  // Examples:
  // flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.100:3007/api/v2
  // flutter run --dart-define=BACKEND_HOST=192.168.1.100
  //
  // Notes:
  // - Physical Android device with `adb reverse`: localhost works.
  // - Physical Android device without reverse: use your computer's LAN IP.
  // - Android emulator without reverse: pass BACKEND_HOST=10.0.2.2.
  // - iOS simulator: localhost works.
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
