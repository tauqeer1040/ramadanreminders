import 'package:firebase_analytics/firebase_analytics.dart';
import 'analytics_protocol.dart';

class AnalyticsService implements AnalyticsProtocol {
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;
  AnalyticsService._();

  FirebaseAnalytics? _analytics;
  FirebaseAnalytics get _ensureAnalytics => _analytics ??= FirebaseAnalytics.instance;
  late final FirebaseAnalyticsObserver _observer = FirebaseAnalyticsObserver(analytics: _ensureAnalytics);

  FirebaseAnalyticsObserver get observer => _observer;

  @override
  Future<void> logEvent(String name, {Map<String, String>? params}) =>
      _ensureAnalytics.logEvent(name: name, parameters: params);

  @override
  Future<void> setUserProperty(String name, String? value) =>
      _ensureAnalytics.setUserProperty(name: name, value: value);

  @override
  Future<void> logScreenView(String screenName) =>
      _ensureAnalytics.logScreenView(screenName: screenName);

  @override
  Future<void> logJournalSaved() => logEvent('journal_saved');

  @override
  Future<void> logJournalWordCount(int wordCount) =>
      logEvent('journal_word_count', params: {'word_count': wordCount.toString()});

  @override
  Future<void> logMoodCheckin(double value) =>
      logEvent('mood_checkin', params: {'mood_value': value.toStringAsFixed(1)});

  @override
  Future<void> logQuranOpened() => logEvent('quran_opened');

  @override
  Future<void> logShopPurchase(String itemId) =>
      logEvent('shop_purchase', params: {'item_id': itemId});

  @override
  Future<void> logShopItemViewed(String itemId) =>
      logEvent('shop_item_viewed', params: {'item_id': itemId});

  @override
  Future<void> logTabViewed(String tabName) =>
      logEvent('tab_viewed', params: {'tab_name': tabName});

  @override
  Future<void> logAppOpen() => logEvent('app_opened');

  @override
  Future<void> logSessionStart() => logEvent('session_started');

  @override
  Future<void> logOnboardingCompleted() => logEvent('onboarding_completed');

  @override
  Future<void> logInsightGenerated({required bool success}) =>
      logEvent('insight_generated', params: {'success': success.toString()});

  @override
  Future<void> logStreakRecorded(int streak) =>
      logEvent('streak_recorded', params: {'streak': streak.toString()});

  @override
  Future<void> logFeatureUsed(String featureName) =>
      logEvent('feature_used', params: {'feature': featureName});

  @override
  Future<void> logFavoriteAdded(String itemId) =>
      logEvent('favorite_added', params: {'item_id': itemId});

  @override
  Future<void> logSearchPerformed(String query) =>
      logEvent('search_performed', params: {'query_length': query.length.toString()});

  @override
  Future<void> logShareContent(String contentType) =>
      logEvent('share_content', params: {'content_type': contentType});
}
