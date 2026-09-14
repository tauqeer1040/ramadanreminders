import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenuecat_service.dart';

/// Unified membership state for Meowmin Max. Single source of truth for every
/// Get Max button, banner, upsell, and the expiry countdown — so the app can
/// never show "buy" and "thank you" at the same time.
///
/// States:
/// * [MaxState.inactive] — no entitlement: show Get Max everywhere.
/// * [MaxState.active] — entitled, no expiry pressure: hide all upsells.
/// * [MaxState.expiringSoon] — entitled but `expirationDate` is within
///   [expiryWindow] (all paid tenures incl. cancelled-but-still-active):
///   hide buttons, show the "Max expiring in N days, please renew" banner.
///   Lifetime purchases never expire, so they stay [MaxState.active] forever.
enum MaxState { inactive, active, expiringSoon }

class MaxStatus {
  final MaxState state;
  final int daysRemaining;
  final bool lifetime;
  final String? productId;
  final String? planLabel;

  const MaxStatus({
    required this.state,
    this.daysRemaining = 0,
    this.lifetime = false,
    this.productId,
    this.planLabel,
  });

  const MaxStatus.inactive()
      : this(state: MaxState.inactive);

  bool get isActive => state != MaxState.inactive;
  bool get showUpsells => state == MaxState.inactive;
  bool get showExpiryBanner => state == MaxState.expiringSoon;
}

class MaxStatusService {
  static const Duration expiryWindow = Duration(days: 3);

  /// Pure resolver over a RevenueCat CustomerInfo — unit-testable, no I/O.
  static MaxStatus fromCustomerInfo(CustomerInfo? info) {
    final entitlement =
        info?.entitlements.active[RevenueCatService.entitlementId];
    if (entitlement == null) return const MaxStatus.inactive();

    final productId = entitlement.productIdentifier;
    if (_isLifetime(productId)) {
      return MaxStatus(
        state: MaxState.active,
        lifetime: true,
        productId: productId,
        planLabel: planLabelFor(productId),
      );
    }

    final expiry = entitlement.expirationDate != null
        ? DateTime.tryParse(entitlement.expirationDate!)
        : null;
    if (expiry == null) {
      // No expiry reported (e.g. sandbox quirk): treat as plain active.
      return MaxStatus(
        state: MaxState.active,
        productId: productId,
        planLabel: planLabelFor(productId),
      );
    }
    final remaining = expiry.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return const MaxStatus.inactive();
    }
    if (remaining <= expiryWindow) {
      final days = remaining.inHours >= 24
          ? (remaining.inHours / 24).ceil()
          : 1;
      return MaxStatus(
        state: MaxState.expiringSoon,
        daysRemaining: days,
        productId: productId,
        planLabel: planLabelFor(productId),
      );
    }
    return MaxStatus(
      state: MaxState.active,
      productId: productId,
      planLabel: planLabelFor(productId),
    );
  }

  static bool _isLifetime(String productId) {
    return productId.toLowerCase().contains('lifetime');
  }

  /// Challenge-language plan label, never billing terms.
  /// monthly|weekly|daily -> 30-day challenge, four-month -> 4-month
  /// challenge, year|annual -> 12-month journey, lifetime -> Lifetime.
  static String planLabelFor(String? productId) {
    final id = (productId ?? '').toLowerCase();
    if (id.isEmpty) return 'Free';
    if (id.contains('lifetime')) return 'Lifetime';
    if (id.contains('four-month') || id.contains('four_month')) {
      return '4-month challenge';
    }
    if (id.contains('year') || id.contains('annual') || id.contains('12')) {
      return '12-month journey';
    }
    if (id.contains('month') || id.contains('week') || id.contains('day')) {
      return '30-day challenge';
    }
    return 'Max';
  }

  /// Current status from the cached CustomerInfo (no network). Falls back to
  /// a live fetch when nothing is cached yet.
  static Future<MaxStatus> current() async {
    try {
      final service = RevenueCatService.instance;
      var info = service.cachedCustomerInfo;
      info ??= await service.getCustomerInfo();
      return fromCustomerInfo(info);
    } catch (e) {
      debugPrint('[MaxStatus] resolve failed: $e');
      return const MaxStatus.inactive();
    }
  }

  /// Live refresh (network) — use on resume and after purchase/restore.
  static Future<MaxStatus> refresh() async {
    try {
      final info = await RevenueCatService.instance.getCustomerInfo();
      return fromCustomerInfo(info);
    } catch (e) {
      debugPrint('[MaxStatus] refresh failed: $e');
      return current();
    }
  }
}
