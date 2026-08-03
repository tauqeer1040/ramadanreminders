abstract class AnalyticsProtocol {
  Future<void> logEvent(String name, {Map<String, String>? params});
  Future<void> setUserProperty(String name, String? value);
  Future<void> logScreenView(String screenName);
  Future<void> logJournalSaved();
  Future<void> logJournalWordCount(int wordCount);
  Future<void> logMoodCheckin(double value);
  Future<void> logQuranOpened();
  Future<void> logShopPurchase(String itemId);
  Future<void> logShopItemViewed(String itemId);
  Future<void> logTabViewed(String tabName);
}
