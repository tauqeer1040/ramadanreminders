import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart' as iap;
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

/// Buys the Streak Shield consumable ($0.99) directly through RevenueCat —
/// no paywall UI. The product (`meowmin_shield`) already exists in the
/// RevenueCat catalog; RC handles the Play Billing sheet, acknowledgement
/// and consumption. On success the purchase is registered with the backend
/// (`/shop/shield-grant`, +1 server balance) and the caller arms or
/// restores locally via [StreakService].
class ShieldBillingService {
  /// Store product id of the shield (matches the RC catalog entry).
  static const String productId = 'meowmin_shield';

  /// Purchases one shield. Returns the server shield balance afterwards.
  /// Direct Google Play bottomsheet via RevenueCat — NO paywall/offering.
  /// Throws [ShieldPurchaseCancelled] when the user dismisses the sheet.
  static Future<int> purchaseShield() async {
    // Fallback identifier: Play one-time products sometimes expose as
    // `productId:default-option` on certain RC SDK / Play Billing paths.
    const candidates = [productId, '${productId}:default-option'];
    List<StoreProduct> products = [];
    for (final id in candidates) {
      try {
        products = await Purchases.getProducts([id]);
        if (products.isNotEmpty) {
          if (id != productId) {
            debugPrint('[Shield] Resolved via fallback id $id');
          }
          break;
        }
        debugPrint('[Shield] getProducts($id) empty, trying next');
      } catch (e) {
        debugPrint('[Shield] getProducts($id) error: $e');
      }
    }

    StoreProduct? product = products.isEmpty ? null : products.first;
    if (product != null) {
      try {
        final result = await Purchases.purchase(
          PurchaseParams.storeProduct(product),
        );
        final token = _latestTransactionId(result.customerInfo);
        return await _grantShield(token);
      } on PlatformException catch (e) {
        if (PurchasesErrorHelper.getErrorCode(e) ==
            PurchasesErrorCode.purchaseCancelledError) {
          debugPrint('[Shield] Purchase cancelled by user');
          throw ShieldPurchaseCancelled();
        }
        debugPrint('[Shield] Purchase failed: $e');
        throw ShieldPurchaseException('Purchase failed. Try again.');
      } catch (e) {
        if (e is ShieldPurchaseException || e is ShieldPurchaseCancelled) {
          rethrow;
        }
        debugPrint('[Shield] Purchase failed: $e');
        throw ShieldPurchaseException('Purchase failed. Try again.');
      }
    }

    // RC product lookup failed (seen on device as productType=subs mismatch
    // while Play has it as INAPP). Fallback to raw Play Billing so the
    // $0.99 sheet still opens — no new RC paywall needed.
    debugPrint('[Shield] RC miss, falling back to raw Play Billing for $productId');
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint(
          '[Shield] Offering all=${offerings.all.keys.toList()} current=${offerings.current?.identifier}');
    } catch (e) {
      debugPrint('[Shield] getOfferings failed: $e');
    }

    return _purchaseViaRawPlayBilling();
  }

  static String? _latestTransactionId(CustomerInfo info) {
    final txns = info.nonSubscriptionTransactions
        .where((t) => t.productIdentifier == productId)
        .toList();
    if (txns.isEmpty) return null;
    txns.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    return txns.first.transactionIdentifier;
  }

  /// Raw Play Billing fallback when RC queries the one-time product as
  /// `subs` (PRODUCT_NOT_FOUND). Uses `flutter_inapp_purchase` directly as
  /// `INAPP` type, shows the same Google bottomsheet, then grants via
  /// the backend + consumes via `finishTransaction`.
  static Future<int> _purchaseViaRawPlayBilling() async {
    final iapConn = iap.FlutterInappPurchase.instance;
    try {
      await iapConn.initConnection();
    } catch (e) {
      debugPrint('[Shield] raw IAP initConnection failed: $e');
      throw ShieldPurchaseException(
          'Streak Shield is not available in the store right now.');
    }

    final completer = Completer<String?>();
    late StreamSubscription<iap.Purchase> subOk;
    late StreamSubscription<iap.PurchaseError> subErr;

    subOk = iapConn.purchaseUpdatedListener.listen((purchase) async {
      try {
        final pid = purchase.productId;
        if (pid != productId && !pid.startsWith(productId)) return;
        if (!completer.isCompleted) completer.complete(purchase.purchaseToken);
        // Acknowledge/consume so it can be bought again (consumable).
        try {
          await iapConn.finishTransaction(
              purchase: purchase, isConsumable: true);
        } catch (e) {
          debugPrint('[Shield] finishTransaction failed: $e');
        }
      } catch (e) {
        debugPrint('[Shield] purchase listener error: $e');
      }
    });

    subErr = iapConn.purchaseErrorListener.listen((err) {
      debugPrint('[Shield] raw purchaseError: ${err.message} code=${err.code}');
      if (!completer.isCompleted) {
        if (err.code == 'E_USER_CANCELLED' ||
            (err.message != null && err.message!.toLowerCase().contains('cancel'))) {
          completer.completeError(ShieldPurchaseCancelled());
        } else {
          completer.completeError(
              ShieldPurchaseException(err.message ?? 'Purchase failed.'));
        }
      }
    });

    try {
      await iapConn.requestPurchase(
        iap.RequestPurchaseProps.inApp(
          (google: iap.RequestPurchaseAndroidProps(skus: [productId]), apple: null),
        ),
      );
      final token = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw ShieldPurchaseException('Purchase timed out. Try again.'),
      );
      return await _grantShield(token);
    } on ShieldPurchaseCancelled {
      rethrow;
    } on ShieldPurchaseException {
      rethrow;
    } catch (e) {
      debugPrint('[Shield] raw purchase failed: $e');
      throw ShieldPurchaseException('Purchase failed. Try again.');
    } finally {
      await subOk.cancel();
      await subErr.cancel();
    }
  }

  /// Registers the verified purchase with the backend. The backend checks
  /// the token against RevenueCat (warn-only) and increments the server
  /// shield balance. Never blocks arming on grant failure — the Play
  /// purchase itself succeeded, so the shield is still granted locally.
  static Future<int> _grantShield(String? purchaseToken) async {
    try {
      final headers = await ApiClient.postHeaders();
      final res = await http
          .post(
            Uri.parse('${AppConstants.backendUrl}/shop/shield-grant'),
            headers: headers,
            body: jsonEncode({
              'productId': productId,
              if (purchaseToken != null && purchaseToken.isNotEmpty)
                'purchaseToken': purchaseToken,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return (body['shields'] as num?)?.toInt() ?? 1;
      }
      debugPrint('[Shield] Grant failed: HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('[Shield] Grant failed: $e');
    }
    return 1;
  }
}

class ShieldPurchaseException implements Exception {
  final String message;
  ShieldPurchaseException(this.message);
  @override
  String toString() => 'ShieldPurchaseException: $message';
}

class ShieldPurchaseCancelled implements Exception {}
