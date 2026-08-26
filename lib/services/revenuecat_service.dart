import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../core/constants.dart';
import '../core/api_client.dart';
import '../core/app_navigator.dart';
import '../screens/web_paywall_screen.dart';

class RevenueCatService {
  static RevenueCatService? _instance;
  static RevenueCatService get instance => _instance ??= RevenueCatService._();
  RevenueCatService._();

  static const String entitlementId = 'Meowmin  Pro';

  static const String _defaultApiKey =
      'test_JaHlwHvOQDMjKOBXtvRVrHQsqsN';

  static const String _defaultWebApiKey =
      'pdl_XjFiWxuHmAwKMGssUknrOGStnEEL';

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
      final effectiveKey = kIsWeb
          ? (webApiKey.isNotEmpty ? webApiKey : _defaultWebApiKey)
          : (apiKey.isNotEmpty ? apiKey : _defaultApiKey);

      await Purchases.setLogLevel(LogLevel.debug);
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

  Future<PurchaseResult> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      _cachedCustomerInfo = result.customerInfo;
      await _syncToBackend(result.customerInfo);
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

  Future<CustomerInfo> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      _cachedCustomerInfo = info;
      await _syncToBackend(info);
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
      debugPrint('[RevenueCat] presentPaywall failed: $e');
      return PaywallResult.error;
    }
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

  Future<PaywallResult> presentPaywallIfNeeded({
    bool displayCloseButton = true,
    Offering? offering,
  }) async {
    try {
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
