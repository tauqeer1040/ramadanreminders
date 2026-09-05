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
  Future<void> logAppOpen();
  Future<void> logSessionStart();
  Future<void> logOnboardingCompleted();
  Future<void> logInsightGenerated({required bool success});
  Future<void> logStreakRecorded(int streak);
  Future<void> logFeatureUsed(String featureName);
  Future<void> logFavoriteAdded(String itemId);
  Future<void> logSearchPerformed(String query);
  Future<void> logShareContent(String contentType);
  // New funnel — 5 core + bonus
  Future<void> logInstall({String? installSource, String? platform, String? browser, String? os});
  Future<void> logSignUp({String? method, int? onboardingStepsCompleted, int? timeToSignUpMs});
  Future<void> logFirstTrueAction({required String which, String? action, int? wordCount});
  Future<void> logTrialStarted({String? trialType, String? trialId, String? priceAfter});
  Future<void> logPurchase({String? value, String? currency, String? transactionId, String? priceId, String? plan, double? valueBeforeDiscount});
  Future<void> logOnboardingStep({required String page, required int index, String? stepName});
  Future<void> logBrowserInfo({String? browser, String? browserVersion, String? os, String? deviceCategory});
  Future<void> logHabitTick({required int activeDaysLast7, required int streakLen, required int totalJournalCount});
}
