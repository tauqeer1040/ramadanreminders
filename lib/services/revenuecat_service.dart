import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/api_client.dart';
import '../core/app_navigator.dart';
import '../screens/demo_paywall_screen.dart';
import '../screens/web_paywall_screen.dart';
import 'analytics_service.dart';

class RevenueCatService {
  static RevenueCatService? _instance;
  static RevenueCatService get instance => _instance ??= RevenueCatService._();
  RevenueCatService._();

  static const String entitlementId = 'Meowmin Max';

  // PROD ONLY — no sandbox. Public SDK keys are safe to ship in the app.
  // --dart-define=REVENUECAT_API_KEY / REVENUECAT_WEB_API_KEY still override
  // when provided, otherwise the hardcoded production keys below are used.
  static const String _defaultApiKey =
      'goog_lmIhhalxbfnLdzYwBuzpiPSoelu';

  static const String _defaultWebApiKey =
      'pdl_JmDRIGIEjpuxaqfLGOuKskkWRNjc';

  final Set<CustomerInfoUpdateListener> _listeners = {};

  CustomerInfo? _cachedCustomerInfo;
  CustomerInfo? get cachedCustomerInfo => _cachedCustomerInfo;

  bool _initialized = false;
  bool get isInitialized => _initialized;
  bool _initializing = false;

  void addListener(CustomerInfoUpdateListener listener) {
    _listeners.add(listener);
    final info = _cachedCustomerInfo;
    if (info != null) {
      listener(info);
    }
  }

  void removeListener(CustomerInfoUpdateListener listener) {
    _listeners.remove(listener);
  }

  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    try {
      final apiKey = const String.fromEnvironment('REVENUECAT_API_KEY');
      final webApiKey = const String.fromEnvironment('REVENUECAT_WEB_API_KEY');
      String effectiveKey = kIsWeb
          ? (webApiKey.isNotEmpty ? webApiKey : _defaultWebApiKey)
          : (apiKey.isNotEmpty ? apiKey : _defaultApiKey);

      if (effectiveKey.isEmpty) {
        throw StateError(
          'RevenueCat API key missing. Production keys are hardcoded; '
          'this should never happen.',
        );
      }

      // Prod-only guard: never allow sandbox test keys, even via dart-define.
      if (effectiveKey.startsWith('test_') ||
          effectiveKey == 'test_JaHlwHvOQDMjKOBXtvRVrHQsqsN' ||
          effectiveKey == 'pdl_XjFiWxuHmAwKMGssUknrOGStnEEL') {
        throw StateError(
          'Sandbox RevenueCat key detected. This app is prod-only.',
        );
      }

      // Debug logs leak user ids/purchase payloads into logcat in release.
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(effectiveKey));

      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);

      try {
        _cachedCustomerInfo = await Purchases.getCustomerInfo();
      } catch (_) {}

      _initialized = true;
      debugPrint('[RevenueCat] Initialized with entitlement: $entitlementId');
    } catch (e) {
      debugPrint('[RevenueCat] Initialization failed: $e');
    } finally {
      _initializing = false;
    }
  }

  /// Idempotent, concurrency-safe initializer. Safe to call from any entry
  /// point (paywall, provider, auth) — guarantees configure() has run before
  /// any Purchases.* call without requiring an eager start at app launch.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (_initializing) {
      // Wait for the in-flight init to complete.
      while (_initializing && !_initialized) {
        await Future.delayed(const Duration(milliseconds: 25));
      }
      return;
    }
    await initialize();
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _cachedCustomerInfo = info;
    for (final listener in _listeners) {
      listener(info);
    }
  }

  Future<void> identify(String userId) async {
    await ensureInitialized();
    if (!_initialized) return;
    try {
      final result = await Purchases.logIn(userId);
      _cachedCustomerInfo = result.customerInfo;
      await _syncToBackend(result.customerInfo);
      final isNew = result.created;
      if (isNew) {
        await Purchases.setAttributes({
          '\$displayName': userId,
        });
      }
      debugPrint('[RevenueCat] Identified user: $userId (created: $isNew)');
    } catch (e) {
      debugPrint('[RevenueCat] identify failed: $e');
    }
  }

  Future<void> reset() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
      _cachedCustomerInfo = null;
      debugPrint('[RevenueCat] Reset');
    } catch (e) {
      debugPrint('[RevenueCat] reset failed: $e');
    }
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      // Self-heal: without configure() this throws for every caller
      // (isSubscribed, purchase flows) and free/paid state reads as
      // "never subscribed". Idempotent — a no-op once initialized.
      await ensureInitialized();
      final info = await Purchases.getCustomerInfo();
      _cachedCustomerInfo = info;
      return info;
    } catch (e) {
      debugPrint('[RevenueCat] getCustomerInfo failed: $e');
      return _cachedCustomerInfo;
    }
  }

  bool hasActiveEntitlement([CustomerInfo? info]) {
    final customerInfo = info ?? _cachedCustomerInfo;
    return customerInfo?.entitlements.active.containsKey(entitlementId) ?? false;
  }

  Future<bool> isSubscribed() async {
    final info = await getCustomerInfo();
    return hasActiveEntitlement(info);
  }

  Offering? _findOffering(Offerings? offerings, {String? identifier}) {
    if (offerings == null) return null;
    if (identifier != null) return offerings.all[identifier];
    return offerings.current;
  }

  Future<Offerings?> getOfferings() async {
    try {
      await ensureInitialized();
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('[RevenueCat] getOfferings failed: $e');
      return null;
    }
  }

  Future<Package?> getPackage({
    String? offeringIdentifier,
    PackageType type = PackageType.weekly,
  }) async {
    try {
      final offerings = await getOfferings();
      if (offerings == null) return null;
      final offering = _findOffering(offerings, identifier: offeringIdentifier);
      return offering?.availablePackages
          .where((p) => p.packageType == type)
          .firstOrNull;
    } catch (e) {
      debugPrint('[RevenueCat] getPackage failed: $e');
      return null;
    }
  }

  static const String _welcomePendingKey = 'max_welcome_pending';
  static const String _welcomeLastShownKey = 'max_welcome_last_shown';

  /// Per-purchase key for the Max thank-you sheet. Uses the active
  /// entitlement's latest purchase date + product id, so renewals and
  /// re-subscribes produce a NEW key (sheet shows again) while the same
  /// purchase dedupes. Falls back to the account purchase date, then a
  /// timestamp (always unique — shows).
  static String welcomeKeyFor(CustomerInfo? info) {
    try {
      final ent = info?.entitlements.active[entitlementId];
      if (ent != null) {
        return '${ent.productIdentifier}@${ent.latestPurchaseDate}';
      }
      final orig = info?.originalPurchaseDate;
      if (orig != null && orig.isNotEmpty) return orig;
    } catch (_) {}
    return 'ts:${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Marks a purchase/restore for the Max thank-you sheet. The sheet
  /// itself dedupes per purchase key (already-seen keys are skipped unless
  /// the caller forces), so this is safe to call from every paywall
  /// success path. Restores pass [forceShow] so the sheet shows even for
  /// an already-seen purchase.
  static Future<void> flagWelcomePending({bool forceShow = false}) async {
    try {
      final info = _instance?._cachedCustomerInfo;
      final key = forceShow
          ? 'restore:${DateTime.now().millisecondsSinceEpoch}'
          : welcomeKeyFor(info);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_welcomePendingKey, key);
      if (forceShow) await prefs.setBool(_welcomeForceKey, true);
    } catch (_) {}
  }

  static const String _welcomeForceKey = 'max_welcome_force';

  static Future<bool> consumeWelcomeForce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_welcomeForceKey) ?? false;
      if (v) await prefs.remove(_welcomeForceKey);
      return v;
    } catch (_) {
      return false;
    }
  }

  /// Renewal catch-up: when the store renewed behind our back (new
  /// latestPurchaseDate since the last shown sheet), stage the new key so
  /// the next showIfPending displays it. Call from cold launch / resume
  /// catch-up points — never from the live update listener (no mid-session
  /// interruptions). Returns true when a renewal was staged.
  static Future<bool> stageRenewalIfNeeded() async {
    try {
      final svc = _instance ?? RevenueCatService._();
      _instance ??= svc;
      CustomerInfo? info = svc._cachedCustomerInfo;
      try {
        info ??= await svc.getCustomerInfo();
      } catch (_) {}
      if (info == null) return false;
      if (!svc.hasActiveEntitlement(info)) return false;
      final key = welcomeKeyFor(info);
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_welcomePendingKey)?.isNotEmpty == true) {
        return false; // a purchase/restore is already queued
      }
      final lastShown = prefs.getString(_welcomeLastShownKey);
      if (lastShown == key) return false;
      if (prefs.getBool('max_welcome_seen_$key') ?? false) return false;
      await prefs.setString(_welcomePendingKey, key);
      debugPrint('[RevenueCat] Renewal staged for thank-you: $key');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> noteWelcomeShown(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_welcomeLastShownKey, key);
    } catch (_) {}
  }

  static Future<String?> consumeWelcomePending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_welcomePendingKey);
      if (key == null || key.isEmpty) return null;
      await prefs.remove(_welcomePendingKey);
      return key;
    } catch (_) {
      return null;
    }
  }

  Future<PurchaseResult> purchasePackage(Package package) async {
    try {
      await ensureInitialized();
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      _cachedCustomerInfo = result.customerInfo;
      await _syncToBackend(result.customerInfo);
      await flagWelcomePending();
      // Log purchase for GA4 funnel
      try {
        final customerInfo = result.customerInfo;
        final activeEntitlements = customerInfo.entitlements.active;
        String? plan;
        if (activeEntitlements.containsKey('Meowmin Max')) {
          plan = 'Meowmin Max';
        }
        AnalyticsService.instance.logPurchase(
          plan: plan,
          value: package.storeProduct.price.toString(),
          currency: package.storeProduct.currencyCode,
          transactionId: customerInfo.originalPurchaseDate,
        );
      } catch (_) {}
      return result;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[RevenueCat] Purchase cancelled');
      } else {
        debugPrint('[RevenueCat] Purchase failed: $e');
      }
      rethrow;
    } catch (e) {
      debugPrint('[RevenueCat] Purchase failed: $e');
      rethrow;
    }
  }

  /// Restores purchases. When an entitlement is found, a FORCED thank-you
  /// is staged so the sheet shows even for an already-seen purchase
  /// (restores always thank). Callers still call showIfPending afterwards.
  Future<CustomerInfo> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      _cachedCustomerInfo = info;
      await _syncToBackend(info);
      if (hasActiveEntitlement(info)) {
        await flagWelcomePending(forceShow: true);
      }
      return info;
    } catch (e) {
      debugPrint('[RevenueCat] Restore failed: $e');
      rethrow;
    }
  }

  Future<PaywallResult> presentPaywall({
    Offering? offering,
    bool displayCloseButton = true,
  }) async {
    try {
      // Belt-and-braces: bootstrap is fire-and-forget, so a fast tap (or a
      // stalled bootstrap) can reach here before configure() ran — the
      // native fragment would silently self-dismiss ("Purchases is not
      // configured"), dead-ending the non-dismissable hard wall.
      await ensureInitialized();
      if (kIsWeb) {
        return await presentWebPaywall(
          offering: offering,
          displayCloseButton: displayCloseButton,
        );
      }
      // Self-heal: the native paywall dismisses itself instantly when the
      // SDK is unconfigured ("Purchases is not configured. Dismissing.")
      // — a silent dead button. Guarantee configure() ran first.
      await ensureInitialized();
      if (!_initialized) {
        debugPrint('[RevenueCat] presentPaywall: SDK not initialized');
        return PaywallResult.error;
      }
      // Prod-only: always use the passed offering or the current
      // (Default 3) production offering. No demo/Test Store routing.
      final result = await RevenueCatUI.presentPaywall(
        offering: offering,
        displayCloseButton: displayCloseButton,
      );
      // Dashboard misconfiguration (e.g. Error 23: no Test Store products)
      // would otherwise leave the user staring at an error screen — show
      // the clearly-labeled demo paywall instead so the flow stays visible.
      if (result == PaywallResult.error) {
        return await _presentDemoPaywall(
          displayCloseButton: displayCloseButton,
        );
      }
      return result;
    } catch (e) {
      debugPrint('[RevenueCat] presentPaywall failed: $e');
      return await _presentDemoPaywall(
        displayCloseButton: displayCloseButton,
      );
    }
  }

  Future<PaywallResult> _presentDemoPaywall({
    bool displayCloseButton = true,
  }) async {
    // Demo fallback is debug-only: release builds must never surface a
    // paywall while on email-only membership (companion mode, Play policy).
    if (!kDebugMode) {
      debugPrint('[RevenueCat] demo paywall suppressed in release');
      return PaywallResult.error;
    }
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[RevenueCat] demo paywall: navigator not ready');
      return PaywallResult.error;
    }
    final result = await navigator.push<PaywallResult>(
      MaterialPageRoute(
        builder: (_) => DemoPaywallScreen(
          displayCloseButton: displayCloseButton,
        ),
      ),
    );
    return result ?? PaywallResult.cancelled;
  }

  /// Presents the custom Flutter paywall on the web, where RevenueCatUI is
  /// not supported. Falls back to a native offering check for safety.
  Future<PaywallResult> presentWebPaywall({
    Offering? offering,
    bool displayCloseButton = true,
  }) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[RevenueCat] presentWebPaywall: navigator not ready');
      return PaywallResult.error;
    }
    final result = await navigator.push<PaywallResult>(
      MaterialPageRoute(
        builder: (_) => WebPaywallScreen(
          offering: offering,
          displayCloseButton: displayCloseButton,
        ),
      ),
    );
    return result ?? PaywallResult.cancelled;
  }

  static const String exitOfferingId = 'expired_winback';

  /// Presents the exit/winback offer. This is the ONLY surface that
  /// advertises the $1-first-month intro — the default paywall never does.
  Future<PaywallResult> presentExitOffer({
    bool displayCloseButton = true,
  }) async {
    try {
      await ensureInitialized();
      Offering? offering;
      try {
        final offerings = await Purchases.getOfferings();
        offering = offerings.all[exitOfferingId];
      } catch (_) {}
      if (kIsWeb) {
        return await presentWebPaywall(
          offering: offering,
          displayCloseButton: displayCloseButton,
        );
      }
      return await RevenueCatUI.presentPaywall(
        offering: offering,
        displayCloseButton: displayCloseButton,
      );
    } catch (e) {
      debugPrint('[RevenueCat] presentExitOffer failed: $e');
      return PaywallResult.error;
    }
  }

  Future<PaywallResult> presentPaywallIfNeeded({
    bool displayCloseButton = true,
    Offering? offering,
  }) async {
    try {
      if (!kIsWeb) {
        await ensureInitialized();
        if (!_initialized) {
          debugPrint('[RevenueCat] presentPaywallIfNeeded: SDK not initialized');
          return PaywallResult.error;
        }
      }
      return await RevenueCatUI.presentPaywallIfNeeded(
        entitlementId,
        offering: offering,
        displayCloseButton: displayCloseButton,
      );
    } catch (e) {
      debugPrint('[RevenueCat] presentPaywallIfNeeded failed: $e');
      return PaywallResult.error;
    }
  }

  Future<void> presentCustomerCenter() async {
    try {
      await RevenueCatUI.presentCustomerCenter(
        onRestoreCompleted: (info) {
          _cachedCustomerInfo = info;
          debugPrint('[RevenueCat] Customer Center restore completed');
          if (hasActiveEntitlement(info)) {
            // Restore via Customer Center always thanks (forced).
            flagWelcomePending(forceShow: true);
          }
        },
        onRestoreFailed: (error) {
          debugPrint('[RevenueCat] Customer Center restore failed: $error');
        },
      );
    } catch (e) {
      debugPrint('[RevenueCat] presentCustomerCenter failed: $e');
    }
  }

  Future<bool> canMakePayments() async {
    try {
      return await Purchases.canMakePayments();
    } catch (e) {
      debugPrint('[RevenueCat] canMakePayments failed: $e');
      return false;
    }
  }

  Future<Map<String, IntroEligibility>> checkTrialEligibility(
    List<String> productIdentifiers,
  ) async {
    try {
      return await Purchases.checkTrialOrIntroductoryPriceEligibility(
        productIdentifiers,
      );
    } catch (e) {
      debugPrint('[RevenueCat] checkTrialEligibility failed: $e');
      return {};
    }
  }

  Future<void> _syncToBackend(CustomerInfo info) async {
    final entitlement = info.entitlements.active[entitlementId];
    if (entitlement == null) return;

    try {
      final headers = await ApiClient.authHeaders();
      int? expiresMs;
      if (entitlement.expirationDate != null) {
        expiresMs = DateTime.tryParse(entitlement.expirationDate!)
            ?.millisecondsSinceEpoch;
      }
      final body = {
        'appUserId': info.originalAppUserId,
        'productId': entitlement.productIdentifier,
        'status': entitlement.isActive ? 'active' : 'expired',
        'expiresAt': expiresMs,
        'periodType': _periodType(entitlement.periodType),
      };
      await http.post(
        Uri.parse('${AppConstants.backendUrl}/subscription/sync'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('[RevenueCat] Backend sync failed: $e');
    }
  }

  String _periodType(PeriodType? type) {
    switch (type) {
      case PeriodType.trial:
        return 'trial';
      case PeriodType.intro:
        return 'intro';
      case PeriodType.prepaid:
        return 'prepaid';
      default:
        return 'normal';
    }
  }
}
