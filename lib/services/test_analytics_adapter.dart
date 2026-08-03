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
}

class AnalyticsEvent {
  final String name;
  final Map<String, String> params;
  const AnalyticsEvent(this.name, this.params);
}
