import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

class TrialStatus {
  final bool trialActive;
  final int daysRemaining;
  final int graceMs;
  final String subscriptionStatus;

  const TrialStatus({
    required this.trialActive,
    required this.daysRemaining,
    required this.graceMs,
    required this.subscriptionStatus,
  });

  bool get canAccess => trialActive || graceMs > 0;

  factory TrialStatus.fromJson(Map<String, dynamic> json) {
    return TrialStatus(
      trialActive: json['trialActive'] as bool,
      daysRemaining: json['daysRemaining'] as int,
      graceMs: json['graceMs'] as int,
      subscriptionStatus: json['subscriptionStatus'] as String,
    );
  }

  factory TrialStatus.fallback() => const TrialStatus(
        trialActive: true,
        daysRemaining: 3,
        graceMs: 1800000,
        subscriptionStatus: 'none',
      );
}

class TrialService {
  static const String _statusCacheKey = 'trial_status_cache_json';
  TrialStatus? _cached;

  Future<TrialStatus> fetchStatus() async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.backendUrl}/trial-status'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('[TrialService] Server returned ${response.statusCode}, using cache');
        return _cachedOrFallback();
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _cached = TrialStatus.fromJson(json);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_statusCacheKey, jsonEncode(json));
      } catch (_) {}
      return _cached!;
    } catch (_) {
      // Offline: last-known server status (short grace), never a fresh grant.
      return _cachedOrFallback();
    }
  }

  /// Offline grace: last-known server verdict. Only when nothing was ever
  /// synced (genuine first-run offline) do we allow the local onboarding
  /// trial — the pending server sync enforces the device claim next online.
  Future<TrialStatus> _cachedOrFallback() async {
    if (_cached != null) return _cached!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_statusCacheKey);
      if (raw != null) {
        _cached = TrialStatus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        return _cached!;
      }
    } catch (_) {}
    return TrialStatus.fallback();
  }

  static Future<TrialStatus> getStatus() async {
    final service = TrialService();
    return service.fetchStatus();
  }

  TrialStatus? get cached => _cached;

  // ── Grace period (server-authoritative) ──────────────────────────

  static Future<int> getRemainingMs() async {
    final status = await TrialService.getStatus();
    return status.graceMs;
  }

  static const String _graceKey = 'grace_remaining_ms';
  static const int _launchCostMs = 60000;

  static Future<int> _readGraceRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_graceKey) ?? 30 * 60 * 1000;
  }

  static Future<void> _writeGraceRemaining(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_graceKey, ms);
  }

  static Future<int> deductLaunchCost() async {
    final current = await _readGraceRemaining();
    final remaining = (current - _launchCostMs).clamp(0, current);
    await _writeGraceRemaining(remaining);
    return remaining;
  }

  static Future<bool> hasGraceRemaining() async {
    final current = await _readGraceRemaining();
    return current > 0;
  }
}
