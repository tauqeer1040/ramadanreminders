import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

class VersionCheckResult {
  final String latestVersion;
  final String minimumVersion;
  final String updateUrl;
  final String updateMessage;
  final bool hasUpdate;
  final bool requiresUpdate;

  VersionCheckResult({
    required this.latestVersion,
    required this.minimumVersion,
    this.updateUrl = '',
    this.updateMessage = '',
    this.hasUpdate = false,
    this.requiresUpdate = false,
  });

  factory VersionCheckResult.fromJson(Map<String, dynamic> json, String currentVersion) {
    final latest = json['latest_app_version'] as String? ?? currentVersion;
    final minimum = json['minimum_app_version'] as String? ?? currentVersion;
    return VersionCheckResult(
      latestVersion: latest,
      minimumVersion: minimum,
      updateUrl: json['update_url'] as String? ?? '',
      updateMessage: json['update_message'] as String? ?? 'A new version is available.',
      hasUpdate: _compareVersions(currentVersion, latest) < 0,
      requiresUpdate: _compareVersions(currentVersion, minimum) < 0,
    );
  }
}

int _compareVersions(String a, String b) {
  final pa = a.split('+')[0].split('.').map(int.tryParse).where((e) => e != null).cast<int>().toList();
  final pb = b.split('+')[0].split('.').map(int.tryParse).where((e) => e != null).cast<int>().toList();
  for (int i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
    final na = i < pa.length ? pa[i] : 0;
    final nb = i < pb.length ? pb[i] : 0;
    if (na > nb) return 1;
    if (na < nb) return -1;
  }
  return 0;
}

class VersionCheckService {
  static Future<VersionCheckResult?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = '${info.version}+${info.buildNumber}';

      final response = await http
          .get(Uri.parse('${AppConstants.backendUrl}/app-version'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return VersionCheckResult.fromJson(data, currentVersion);
    } catch (_) {
      return null;
    }
  }

  static Future<void> showUpdateDialog(BuildContext context, VersionCheckResult result, {bool force = false}) async {
    await showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) => PopScope(
        canPop: !force,
        child: AlertDialog(
          title: const Text('Update Available'),
          content: Text(result.updateMessage.isNotEmpty
              ? result.updateMessage
              : 'Version ${result.latestVersion} is available. You are on ${result.minimumVersion}.'),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
            TextButton(
              onPressed: () {
                final url = result.updateUrl;
                if (url.isNotEmpty) {
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
                if (force) Navigator.pop(ctx);
              },
              child: const Text('Update'),
            ),
            if (force)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Exit App'),
              ),
          ],
        ),
      ),
    );
  }
}
