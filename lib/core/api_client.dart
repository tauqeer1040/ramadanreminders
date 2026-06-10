import 'package:firebase_auth/firebase_auth.dart';

class ApiClient {
  static Future<Map<String, String>> authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, String>> postHeaders() async {
    final headers = await authHeaders();
    headers['Content-Type'] = 'application/json';
    return headers;
  }
}
