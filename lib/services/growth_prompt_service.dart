import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for growth-prompt policy (review asks and share
/// nudges). Prompts — never user-initiated taps — are throttled here.
///
/// Review policy:
/// - A self-reported 4- or 5-star rating stops review prompts permanently.
/// - A low (1-3 star) rating suppresses review prompts for 30 days.
/// - Otherwise review is offered at most once per app version.
/// Share policy:
/// - Max 2 shares per rolling 7-day window (counted on share tap).
/// - A 7-day snooze silences both prompts.
class GrowthPromptService {
  static const String _reviewHighRating = 'growth_review_high_rating';
  static const String _reviewLowRatingUntilMs =
      'growth_review_low_rating_until_ms';
  static const String _reviewOfferedVersion = 'growth_review_offered_version';
  // Legacy key written by the delight sheet before this service existed.
  static const String _legacyReviewAskedVersion =
      'delight_review_asked_version';
  static const String _shareCount = 'growth_share_count';
  static const String _shareWindowStartMs = 'growth_share_window_start_ms';
  static const String _snoozeUntilMs = 'growth_snooze_until_ms';
  static const String _sheetLastShownMs = 'delight_sheet_last_shown_ms';
  static const String _nextAction = 'delight_next_action';

  static const Duration shareWindow = Duration(days: 7);
  static const int shareMaxPerWindow = 2;
  static const Duration sheetThrottle = Duration(hours: 24);
  static const Duration lowRatingSuppress = Duration(days: 30);

  static Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  /// True once the user self-reported a 4- or 5-star rating. Callers hide
  /// (not just suppress) review entry points on this signal.
  static Future<bool> hasHighRating() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_reviewHighRating) ?? false) return true;
    // Back-compat: the old 5-star-only flag means the same thing.
    return prefs.getBool('growth_review_rated_5_star') ?? false;
  }

  static Future<bool> isSnoozed() async {
    final prefs = await SharedPreferences.getInstance();
    return DateTime.now().millisecondsSinceEpoch <
        (prefs.getInt(_snoozeUntilMs) ?? 0);
  }

  static Future<void> snooze({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _snoozeUntilMs,
      DateTime.now().millisecondsSinceEpoch +
          Duration(days: days).inMilliseconds,
    );
  }

  static Future<bool> shouldOfferReview() async {
    final prefs = await SharedPreferences.getInstance();
    if (await isSnoozed()) return false;
    if (await hasHighRating()) return false;
    if (DateTime.now().millisecondsSinceEpoch <
        (prefs.getInt(_reviewLowRatingUntilMs) ?? 0)) {
      return false;
    }
    final version = await currentVersion();
    if (prefs.getString(_reviewOfferedVersion) == version) return false;
    if (prefs.getString(_legacyReviewAskedVersion) == version) return false;
    return true;
  }

  static Future<void> recordReviewOffered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reviewOfferedVersion, await currentVersion());
  }

  /// 4 or 5 stars: stop review prompts permanently.
  static Future<void> recordHighRating() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewHighRating, true);
    await prefs.setString(_reviewOfferedVersion, await currentVersion());
  }

  /// 1-3 stars: suppress review prompts for a while (30 days).
  static Future<void> recordLowRating() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _reviewLowRatingUntilMs,
      DateTime.now().millisecondsSinceEpoch + lowRatingSuppress.inMilliseconds,
    );
  }

  static Future<bool> shouldOfferShare() async {
    if (await isSnoozed()) return false;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowStart = prefs.getInt(_shareWindowStartMs) ?? 0;
    if (now - windowStart >= shareWindow.inMilliseconds) return true;
    return (prefs.getInt(_shareCount) ?? 0) < shareMaxPerWindow;
  }

  static Future<void> recordShare() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowStart = prefs.getInt(_shareWindowStartMs) ?? 0;
    if (now - windowStart >= shareWindow.inMilliseconds) {
      await prefs.setInt(_shareWindowStartMs, now);
      await prefs.setInt(_shareCount, 1);
    } else {
      await prefs.setInt(_shareCount, (prefs.getInt(_shareCount) ?? 0) + 1);
    }
  }

  /// Sheet-level throttle: at most one delight sheet per 24h.
  static Future<bool> shouldShowSheet() async {
    if (await isSnoozed()) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt(_sheetLastShownMs) ?? 0;
    return DateTime.now().millisecondsSinceEpoch - lastShown >=
        sheetThrottle.inMilliseconds;
  }

  static Future<void> recordSheetShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _sheetLastShownMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<String> nextActionName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nextAction) ?? 'review';
  }

  static Future<void> flipNextAction(String shown) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _nextAction,
      shown == 'review' ? 'share' : 'review',
    );
  }
}
