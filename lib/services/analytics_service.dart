import 'package:firebase_analytics/firebase_analytics.dart';
import 'analytics_protocol.dart';

class AnalyticsService implements AnalyticsProtocol {
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;
  AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  late final FirebaseAnalyticsObserver _observer = FirebaseAnalyticsObserver(analytics: _analytics);

  FirebaseAnalyticsObserver get observer => _observer;

  @override
  Future<void> logEvent(String name, {Map<String, String>? params}) =>
      _analytics.logEvent(name: name, parameters: params);

  @override
  Future<void> setUserProperty(String name, String? value) =>
      _analytics.setUserProperty(name: name, value: value);

  @override
  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName);

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
}
