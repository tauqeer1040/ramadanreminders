import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;
  AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  late final FirebaseAnalyticsObserver _observer = FirebaseAnalyticsObserver(analytics: _analytics);

  FirebaseAnalyticsObserver get observer => _observer;

  Future<void> logJournalSaved() =>
      _analytics.logEvent(name: 'journal_saved');

  Future<void> logMoodCheckin(double value) =>
      _analytics.logEvent(name: 'mood_checkin', parameters: {'value': value.toStringAsFixed(2)});

  Future<void> logInsightViewed({String? reference}) =>
      _analytics.logEvent(name: 'insight_viewed', parameters: {
        if (reference != null) 'reference': reference,
      });

  Future<void> logShopPurchase(String itemId) =>
      _analytics.logEvent(name: 'shop_purchase', parameters: {'item_id': itemId});

  Future<void> logStreakMilestone(int streak) =>
      _analytics.logEvent(name: 'streak_milestone', parameters: {'streak': streak.toString()});

  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName);

  Future<void> logSignIn(String method) =>
      _analytics.logEvent(name: 'sign_in', parameters: {'method': method});

  Future<void> logOnboardingComplete() =>
      _analytics.logEvent(name: 'onboarding_complete');

  Future<void> logAppRatingPrompt() =>
      _analytics.logEvent(name: 'app_rating_prompt');
}
