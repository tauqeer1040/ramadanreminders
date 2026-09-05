import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/constants.dart';
import 'analytics_service.dart';

/// Client for the Netflix-style email-continuation flow:
/// mint token + delight email → status polling → unlock on purchase.
/// Raw tokens live only in secure storage and transit to the backend/Paddle;
/// only SHA-256 hashes are ever stored server-side.
class EmailContinueService {
  static const _tokKey = 'email_continue_tok';
  static const _emailKey = 'email_continue_email';
  static const _channel = MethodChannel('com.taucity.meowmin/widget');
  static const _storage = FlutterSecureStorage();

  static Future<void> storeSession(String tok, String email) async {
    await _storage.write(key: _tokKey, value: tok);
    await _storage.write(key: _emailKey, value: email);
  }

  static Future<String?> storedTok() => _storage.read(key: _tokKey);
  static Future<String?> storedEmail() => _storage.read(key: _emailKey);

  static Future<void> clearSession() async {
    await _storage.delete(key: _tokKey);
    await _storage.delete(key: _emailKey);
  }

  /// Mint a continue token + send the delight email. Returns backend JSON
  /// ({tok, emailed, email_masked, expires_in}) or null on failure.
  static Future<Map<String, dynamic>?> mint({
    required String email,
    String? displayName,
    Map<String, dynamic>? snapshot,
  }) async {
    try {
      final headers = await ApiClient.postHeaders();
      final res = await http
          .post(
            Uri.parse('${AppConstants.backendUrl}/email-continue'),
            headers: headers,
            body: jsonEncode({
              'email': email,
              if (displayName != null) 'displayName': displayName,
              'snapshot': snapshot,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tok = json['tok'] as String?;
      if (tok != null && tok.isNotEmpty) {
        await storeSession(tok, email);
        try {
          AnalyticsService.instance.logEvent('email_continue_sent');
        } catch (_) {}
      }
      return json;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> resend(String email) async {
    try {
      final headers = await ApiClient.postHeaders();
      final res = await http
          .post(
            Uri.parse('${AppConstants.backendUrl}/email-continue/resend'),
            headers: headers,
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tok = json['tok'] as String?;
      if (tok != null && tok.isNotEmpty) await storeSession(tok, email);
      try {
        AnalyticsService.instance.logEvent('email_continue_resent');
      } catch (_) {}
      return json;
    } catch (_) {
      return null;
    }
  }

  /// Returns {'valid': bool, 'purchased': bool} or null on transport failure.
  static Future<Map<String, dynamic>?> pollStatus(String tok) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http
          .get(
            Uri.parse('${AppConstants.backendUrl}/continue-status?tok=${Uri.encodeQueryComponent(tok)}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Opens Gmail when installed, else the device mail client
  /// (CATEGORY_APP_EMAIL). Returns false when unavailable — caller shows
  /// copy-address + provider fallbacks.
  /// Never opens a purchase URL: compliance-safe on Android.
  static Future<bool> openEmailApp() async {
    if (kIsWeb) return false;
    try {
      if (defaultTargetPlatform != TargetPlatform.android) return false;
      try {
        final gmail = await _channel.invokeMethod<bool>('openGmailApp');
        if (gmail == true) {
          try {
            AnalyticsService.instance.logEvent(
              'email_app_opened',
              params: {'app': 'gmail'},
            );
          } catch (_) {}
          return true;
        }
      } catch (_) {
        // fall through to the generic email intent
      }
      final opened = await _channel.invokeMethod<bool>('openEmailApp');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return '•••';
    final local = parts[0];
    return '${local.isEmpty ? '' : local[0]}•••@${parts[1]}';
  }
}
