import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/constants.dart';

class UserService {
  static Future<void> syncUser(User user) async {
    try {
      final headers = await ApiClient.postHeaders();
      await http.post(
        Uri.parse('${AppConstants.backendUrl}/user/upsert'),
        headers: headers,
        body: jsonEncode({
          'displayName': user.displayName,
          'email': user.email,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[UserService] syncUser error: $e');
    }
  }

  static Future<void> deleteUserAccount(User user) async {
    try {
      await user.delete();
    } catch (e) {
      debugPrint("User deletion error: $e");
      rethrow;
    }
  }
}
