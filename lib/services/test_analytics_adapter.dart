import 'analytics_protocol.dart';

class TestAnalyticsAdapter implements AnalyticsProtocol {
  final List<AnalyticsEvent> events = [];
  final Map<String, String?> _props = {};

  @override
  Future<void> logEvent(String name, {Map<String, String>? params}) async {
    events.add(AnalyticsEvent(name, params ?? {}));
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    _props[name] = value;
  }

  @override
  Future<void> logScreenView(String screenName) async {
    events.add(AnalyticsEvent('screen_view', {'screen': screenName}));
  }

  @override
  Future<void> logJournalSaved() async {
    events.add(const AnalyticsEvent('journal_saved', {}));
  }

  @override
  Future<void> logJournalWordCount(int wordCount) async {
    events.add(AnalyticsEvent('journal_word_count', {'word_count': wordCount.toString()}));
  }

  @override
  Future<void> logMoodCheckin(double value) async {
    events.add(AnalyticsEvent('mood_checkin', {'mood_value': value.toStringAsFixed(1)}));
  }

  @override
  Future<void> logQuranOpened() async {
    events.add(const AnalyticsEvent('quran_opened', {}));
  }

  @override
  Future<void> logShopPurchase(String itemId) async {
    events.add(AnalyticsEvent('shop_purchase', {'item_id': itemId}));
  }

  @override
  Future<void> logShopItemViewed(String itemId) async {
    events.add(AnalyticsEvent('shop_item_viewed', {'item_id': itemId}));
  }

  @override
  Future<void> logTabViewed(String tabName) async {
    events.add(AnalyticsEvent('tab_viewed', {'tab_name': tabName}));
  }

  @override
  Future<void> logAppOpen() async {
    events.add(const AnalyticsEvent('app_open', {}));
  }

  @override
  Future<void> logSessionStart() async {
    events.add(const AnalyticsEvent('session_start', {}));
  }

  @override
  Future<void> logOnboardingCompleted() async {
    events.add(const AnalyticsEvent('onboarding_completed', {}));
  }

  @override
  Future<void> logInsightGenerated({required bool success}) async {
    events.add(AnalyticsEvent('insight_generated', {'success': success.toString()}));
  }

  @override
  Future<void> logStreakRecorded(int streak) async {
    events.add(AnalyticsEvent('streak_recorded', {'streak': streak.toString()}));
  }

  @override
  Future<void> logFeatureUsed(String featureName) async {
    events.add(AnalyticsEvent('feature_used', {'feature': featureName}));
  }

  @override
  Future<void> logFavoriteAdded(String itemId) async {
    events.add(AnalyticsEvent('favorite_added', {'item_id': itemId}));
  }

  @override
  Future<void> logSearchPerformed(String query) async {
    events.add(AnalyticsEvent('search_performed', {'query_length': query.length.toString()}));
  }

  @override
  Future<void> logShareContent(String contentType) async {
    events.add(AnalyticsEvent('share_content', {'content_type': contentType}));
  }
}

class AnalyticsEvent {
  final String name;
  final Map<String, String> params;
  const AnalyticsEvent(this.name, this.params);
}
