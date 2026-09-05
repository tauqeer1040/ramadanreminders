import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
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
  Future<void> logEvent(String name, {Map<String, String>? params}) {
    // also attach browser info for iOS audience
    return _ensureAnalytics.logEvent(name: name, parameters: params);
  }

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

  @override
  Future<void> logInstall({String? installSource, String? platform, String? browser, String? os}) => logEvent('app_install', params: {
        if (installSource != null) 'install_source': installSource,
        'platform': platform ?? (kIsWeb ? 'web' : defaultTargetPlatform.name),
        if (browser != null) 'browser': browser,
        if (os != null) 'os': os,
      });

  @override
  Future<void> logSignUp({String? method, int? onboardingStepsCompleted, int? timeToSignUpMs}) => logEvent('sign_up', params: {
        if (method != null) 'method': method,
        if (onboardingStepsCompleted != null) 'onboarding_steps_completed': onboardingStepsCompleted.toString(),
        if (timeToSignUpMs != null) 'time_to_sign_up_ms': timeToSignUpMs.toString(),
      });

  @override
  Future<void> logFirstTrueAction({required String which, String? action, int? wordCount}) {
    // which: journal | scratch | any
    return logEvent('first_true_action', params: {
      'which': which,
      if (action != null) 'action': action,
      if (wordCount != null) 'word_count': wordCount.toString(),
    });
  }

  @override
  Future<void> logTrialStarted({String? trialType, String? trialId, String? priceAfter}) => logEvent('trial_started', params: {
        if (trialType != null) 'trial_type': trialType,
        if (trialId != null) 'trial_id': trialId,
        if (priceAfter != null) 'price_after': priceAfter,
      });

  @override
  Future<void> logPurchase({String? value, String? currency, String? transactionId, String? priceId, String? plan, double? valueBeforeDiscount}) => logEvent('purchase', params: {
        if (value != null) 'value': value,
        if (currency != null) 'currency': currency,
        if (transactionId != null) 'transaction_id': transactionId,
        if (priceId != null) 'price_id': priceId,
        if (plan != null) 'plan': plan,
        if (valueBeforeDiscount != null) 'value_before_discount': valueBeforeDiscount.toString(),
      });

  @override
  Future<void> logOnboardingStep({required String page, required int index, String? stepName}) {
    setUserProperty('last_onboarding_step', page);
    return logEvent('onboarding_step_viewed', params: {
      'page': page,
      'step_index': index.toString(),
      if (stepName != null) 'step_name': stepName,
    });
  }

  @override
  Future<void> logBrowserInfo({String? browser, String? browserVersion, String? os, String? deviceCategory}) {
    if (browser != null) setUserProperty('browser', browser);
    if (os != null) setUserProperty('os', os);
    return logEvent('browser_info', params: {
      if (browser != null) 'browser': browser,
      if (browserVersion != null) 'browser_version': browserVersion,
      if (os != null) 'os': os,
      if (deviceCategory != null) 'device_category': deviceCategory,
    });
  }

  @override
  Future<void> logHabitTick({required int activeDaysLast7, required int streakLen, required int totalJournalCount}) {
    setUserProperty('active_days_7d', activeDaysLast7.toString());
    return logEvent('habit_tick', params: {
      'active_days_7d': activeDaysLast7.toString(),
      'streak_len': streakLen.toString(),
      'total_journal_count': totalJournalCount.toString(),
    });
  }
}
