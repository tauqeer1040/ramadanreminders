import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;
  AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  late final FirebaseAnalyticsObserver _observer = FirebaseAnalyticsObserver(analytics: _analytics);

  FirebaseAnalyticsObserver get observer => _observer;

  // ── User Properties ────────────────────────────────────────────────

  Future<void> setUserProperty(String name, String? value) =>
      _analytics.setUserProperty(name: name, value: value);

  Future<void> setUserId(String? id) =>
      _analytics.setUserId(id: id);

  // ── Onboarding Events ──────────────────────────────────────────────

  Future<void> logOnboardingStarted() =>
      _analytics.logEvent(name: 'onboarding_started');

  Future<void> logOnboardingPageViewed(String pageName) =>
      _analytics.logEvent(name: 'onboarding_page_viewed', parameters: {
        'page_name': pageName,
      });

  Future<void> logOnboardingMusicSelected(int trackIndex) =>
      _analytics.logEvent(name: 'onboarding_music_selected', parameters: {
        'track_index': trackIndex.toString(),
      });

  Future<void> logOnboardingNamesEntered() =>
      _analytics.logEvent(name: 'onboarding_names_entered');

  Future<void> logOnboardingAgeSet(int age) =>
      _analytics.logEvent(name: 'onboarding_age_set', parameters: {
        'age_bracket': _ageBracket(age),
      });

  Future<void> logOnboardingPhoneHours(int hours) =>
      _analytics.logEvent(name: 'onboarding_phone_hours', parameters: {
        'hours': hours.toString(),
        'hours_bucket': _hoursBucket(hours),
      });

  Future<void> logOnboardingHardQuestionsChosen(bool choseHard) =>
      _analytics.logEvent(name: 'onboarding_hard_questions_chosen', parameters: {
        'chose_hard': choseHard ? 'true' : 'false',
      });

  Future<void> logOnboardingMillionDollars() =>
      _analytics.logEvent(name: 'onboarding_million_dollars');

  Future<void> logOnboardingWakeupChoice() =>
      _analytics.logEvent(name: 'onboarding_wakeup_choice');

  Future<void> logOnboardingCommitmentMade() =>
      _analytics.logEvent(name: 'onboarding_commitment_made');

  Future<void> logOnboardingFirstJournalWritten(int wordCount) =>
      _analytics.logEvent(name: 'onboarding_first_journal_written', parameters: {
        'word_count': wordCount.toString(),
      });

  Future<void> logOnboardingInsightGenerated({required bool success, int? cardCount}) =>
      _analytics.logEvent(name: 'onboarding_insight_generated', parameters: {
        'success': success ? 'true' : 'false',
        if (cardCount != null) 'card_count': cardCount.toString(),
      });

  Future<void> logOnboardingScratchRevealed(int count) =>
      _analytics.logEvent(name: 'onboarding_scratch_revealed', parameters: {
        'count': count.toString(),
      });

  Future<void> logOnboardingSummaryViewed() =>
      _analytics.logEvent(name: 'onboarding_summary_viewed');

  Future<void> logOnboardingGoogleSignIn({required String action}) =>
      _analytics.logEvent(name: 'onboarding_google_signin', parameters: {
        'action': action,
      });

  Future<void> logOnboardingComplete() =>
      _analytics.logEvent(name: 'onboarding_complete');

  Future<void> logOnboardingAbandoned(String pageName) =>
      _analytics.logEvent(name: 'onboarding_abandoned', parameters: {
        'last_page': pageName,
      });

  // ── App Lifecycle ──────────────────────────────────────────────────

  Future<void> logAppLaunch() =>
      _analytics.logEvent(name: 'app_launch');

  Future<void> logAppBackground() =>
      _analytics.logEvent(name: 'app_background');

  Future<void> logAppForeground() =>
      _analytics.logEvent(name: 'app_foreground');

  Future<void> logSessionEnd(int durationSeconds) =>
      _analytics.logEvent(name: 'session_end', parameters: {
        'duration_seconds': durationSeconds.toString(),
      });

  // ── Tab / Navigation ───────────────────────────────────────────────

  Future<void> logTabViewed(String tabName) =>
      _analytics.logEvent(name: 'tab_viewed', parameters: {
        'tab_name': tabName,
      });

  // ── Journal Events (existing expanded) ─────────────────────────────

  Future<void> logJournalSaved() =>
      _analytics.logEvent(name: 'journal_saved');

  Future<void> logJournalWordCount(int count) =>
      _analytics.logEvent(name: 'journal_word_count', parameters: {
        'word_count': count.toString(),
      });

  Future<void> logJournalDeleted() =>
      _analytics.logEvent(name: 'journal_deleted');

  Future<void> logJournalFavorited() =>
      _analytics.logEvent(name: 'journal_favorited');

  Future<void> logJournalUnfavorited() =>
      _analytics.logEvent(name: 'journal_unfavorited');

  Future<void> logJournalHistoryViewed() =>
      _analytics.logEvent(name: 'journal_history_viewed');

  // ── Mood ───────────────────────────────────────────────────────────

  Future<void> logMoodCheckin(double value) =>
      _analytics.logEvent(name: 'mood_checkin', parameters: {
        'value': value.toStringAsFixed(2),
        'value_bucket': _moodBucket(value),
      });

  // ── Insights ───────────────────────────────────────────────────────

  Future<void> logInsightViewed({String? reference}) =>
      _analytics.logEvent(name: 'insight_viewed', parameters: {
        if (reference != null) 'reference': reference,
      });

  // ── Shop ───────────────────────────────────────────────────────────

  Future<void> logShopItemViewed(String itemId) =>
      _analytics.logEvent(name: 'shop_item_viewed', parameters: {
        'item_id': itemId,
      });

  Future<void> logShopPurchase(String itemId) =>
      _analytics.logEvent(name: 'shop_purchase', parameters: {
        'item_id': itemId,
      });

  // ── Streak ─────────────────────────────────────────────────────────

  Future<void> logStreakMilestone(int streak) =>
      _analytics.logEvent(name: 'streak_milestone', parameters: {
        'streak': streak.toString(),
      });

  Future<void> logStreakPrimeRewardClaimed(int streak) =>
      _analytics.logEvent(name: 'streak_prime_reward_claimed', parameters: {
        'streak': streak.toString(),
      });

  // ── Auth ───────────────────────────────────────────────────────────

  Future<void> logSignIn(String method) =>
      _analytics.logEvent(name: 'sign_in', parameters: {
        'method': method,
      });

  Future<void> logSignUp(String method) =>
      _analytics.logEvent(name: 'sign_up', parameters: {
        'method': method,
      });

  Future<void> logSignOut() =>
      _analytics.logEvent(name: 'sign_out');

  // ── Feature Usage ──────────────────────────────────────────────────

  Future<void> logQuranOpened() =>
      _analytics.logEvent(name: 'quran_opened');

  Future<void> logTasbihUsed(int count) =>
      _analytics.logEvent(name: 'tasbih_used', parameters: {
        'count': count.toString(),
      });

  Future<void> logPrayerTimesViewed() =>
      _analytics.logEvent(name: 'prayer_times_viewed');

  Future<void> logAudioTrackPlayed(String trackName) =>
      _analytics.logEvent(name: 'audio_track_played', parameters: {
        'track_name': trackName,
      });

  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName);

  // ── App Rating ─────────────────────────────────────────────────────

  Future<void> logAppRatingPrompt() =>
      _analytics.logEvent(name: 'app_rating_prompt');

  // ── Helpers ────────────────────────────────────────────────────────

  String _ageBracket(int age) {
    if (age < 18) return 'under_18';
    if (age < 25) return '18_24';
    if (age < 35) return '25_34';
    if (age < 50) return '35_49';
    return '50_plus';
  }

  String _hoursBucket(int hours) {
    if (hours <= 2) return '0_2';
    if (hours <= 4) return '3_4';
    if (hours <= 6) return '5_6';
    if (hours <= 8) return '7_8';
    return '9_plus';
  }

  String _moodBucket(double value) {
    if (value <= 2) return 'low';
    if (value <= 4) return 'medium';
    return 'high';
  }
}
