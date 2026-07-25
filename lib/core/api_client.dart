import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ApiClient {
  static String? _appVersion;

  static Future<String> _getAppVersion() async {
    if (_appVersion != null) return _appVersion!;
    final info = await PackageInfo.fromPlatform();
    _appVersion = '${info.version}+${info.buildNumber}';
    return _appVersion!;
  }

  static Future<Map<String, String>> authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final token = await user.getIdToken();
    final version = await _getAppVersion();
    return {
      'Authorization': 'Bearer $token',
      'X-App-Version': version,
    };
  }

  static Future<Map<String, String>> postHeaders() async {
    final headers = await authHeaders();
    headers['Content-Type'] = 'application/json';
    return headers;
  }

  static bool isUpgradeRequired(int statusCode) {
    return statusCode == 426;
  }
}
