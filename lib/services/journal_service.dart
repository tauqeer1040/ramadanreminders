import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/bullet_item.dart';
import 'journal_local_storage.dart';
import 'journal_remote_storage.dart';
import 'journal_sync_service.dart';
import 'trial_service.dart';

class JournalService {
  final _local = JournalLocalStorage();
  final _remote = JournalRemoteStorage();

  /// Bumped whenever local journals change (saved, deleted, or pulled from
  /// cloud). UI widgets listen so history/stats refresh after sign-in.
  static final ValueNotifier<int> localJournalsVersion = ValueNotifier<int>(0);

  static void notifyJournalsChanged() {
    localJournalsVersion.value++;
  }

  // --- Local storage delegation ---

  Future<void> saveJournalGratitude(String date, String gratitude) => _local.saveGratitude(date, gratitude);
  Future<String> loadJournalGratitude(String date) => _local.loadGratitude(date);
  Future<void> saveJournalTasks(String date, List<BulletItem> tasks) => _local.saveTasks(date, tasks);
  Future<List<BulletItem>> loadJournalTasks(String date) => _local.loadTasks(date);
  Future<void> saveReflectionTasks(List<BulletItem> tasks) => _local.saveReflectionTasks(tasks);
  Future<List<BulletItem>> loadReflectionTasks() => _local.loadReflectionTasks();
  Future<List<String>> getStoredDates() => _local.getStoredDates();

  // --- Static local storage delegation ---

  static Future<void> saveLocalJournalWithId(String id, String text) async {
    await JournalLocalStorage.saveText(id, text);
    JournalSyncService.triggerSync();
    notifyJournalsChanged();
  }

  static Future<Map<String, String>?> loadTodayJournal() async {
    final today = _formatDate(DateTime.now());
    return JournalLocalStorage.loadTodayJournal(today);
  }

  /// Return encrypted journals for safe list rendering.  Call [decryptText]
  /// only when opening a specific entry.
  static Future<List<Map<String, String>>> getEncryptedLocalJournals() =>
      JournalLocalStorage.getEncryptedJournals();

  /// Decrypt a single journal entry on demand.
  static Future<String?> decryptJournal(String encrypted) =>
      JournalLocalStorage.decryptText(encrypted);

  /// Warm the in-memory encrypted cache (call after crypto is ready).
  static Future<void> warmEncryptedCache() => JournalLocalStorage.warmCache();

  static Future<List<Map<String, String>>> getAllLocalJournals() => JournalLocalStorage.getAllTexts();
  static Future<void> deleteLocalJournal(String id) async {
    await JournalLocalStorage.deleteEntry(id);
    notifyJournalsChanged();
  }
  static Future<void> toggleFavorite(String date) async {
    await JournalLocalStorage.toggleFavorite(date);
    notifyJournalsChanged();
  }
  static Future<bool> isFavorited(String date) => JournalLocalStorage.isFavorited(date);
  static Future<List<String>> getFavoriteDates() => JournalLocalStorage.getFavoriteDates();
  static Future<Map<String, dynamic>?> getLocalYesterdayJournalInsight() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = _formatDate(yesterday);
    return JournalLocalStorage.getCachedInsight(dateStr);
  }

  // --- Remote storage delegation ---

  Future<List<BulletItem>> fetchLatestAIDrivenTasks(String uid) => _remote.fetchLatestTasks(uid);
  static Future<Map<String, dynamic>?> getYesterdayJournalInsight() => JournalRemoteStorage.getYesterdayInsight();

  // --- Cross-cutting / utility ---

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String formatDisplayDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dateOnly = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr;
      final parts = dateOnly.split('-');
      if (parts.length != 3) return dateStr;
      final int year = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int day = int.parse(parts[2]);
      final months = [
        "", "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
      ];
      String suffix = 'th';
      if (day == 1 || day == 21 || day == 31) {
        suffix = 'st';
      } else if (day == 2 || day == 22) {
        suffix = 'nd';
      } else if (day == 3 || day == 23) {
        suffix = 'rd';
      }
      final safeMonth = (month >= 1 && month <= 12) ? months[month] : '';
      return '$day$suffix $safeMonth $year';
    } catch (_) {
      return dateStr;
    }
  }

  static Future<bool> isGuestLimitReached() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) return false;
    final status = await TrialService.getStatus();
    return !status.trialActive;
  }
}
